#encoding: utf-8
# Ratatosk
#
# Ratatosk is a facade for dealing with taxa from external name providers.  It
# provides a relatively straightforward interface for getting taxonomic data
# without worrying about where it came from.
#
# At present, Ratatosk is tightly coupled to iNaturalist's model of a Taxon
# having many TaxonNames, and the taxonomy represented as nested sets (using
# the awesome_nested_set plugin).  There's some potential for abstraction here
# (configure what classes handle the taxonomy and what classes handled names;
# support for different tree models), but I think I might have to see some
# demonstrable demand before making that work.
#
# Ratatosk is named after the mythological Norse gossip squirrel of the World
# Tree, Yggdrasil (http://en.wikipedia.org/wiki/Ratatosk).  He deals in
# information.
#

require ::File.expand_path('../ratatosk/name_providers',  __FILE__)

class RatatoskGraftError < StandardError; end

module Ratatosk
  
  class << self
    #
    # Alias for Ratatosk::Ratatosk#find
    #
    def find(name)
      ratatosk.find(name)
    end
    
    #
    # Alias for Ratatosk::Ratatosk#graft
    #
    def graft(taxon, options = {})
      ratatosk.graft(taxon, options)
    end
    
    #
    # Alias for Ratatosk::Ratatosk#find_existing_taxon
    #
    def find_existing_taxon(taxon)
      ratatosk.find_existing_taxon(taxon)
    end

    def name_providers
      ratatosk.name_providers
    end

    def ratatosk
      @ratatosk ||= Ratatosk.new
    end
  end
  
  class Ratatosk
    attr_reader :name_providers

    # Create a new Ratatosk instance
    #
    # * [name_providers] array of NameProvider instances to use as providers.  Can also be specified as an array of prefixes, e.g. ['col', 'ubio']
    def initialize(params = {})
      @name_providers = if params[:name_providers] && !params[:name_providers].first.respond_to?(:get_lineage_for)
        params[:name_providers].map do |prefix|
          if class_name = NameProviders.constants.detect{|c| c.to_s.downcase == "#{prefix}NameProvider".downcase}
            NameProviders.const_get(class_name).new
          end
        end.compact
      else
        params[:name_providers]
      end
      # include all name providers by default, starting with the most taxonomically 
      # and geographically general
      if @name_providers.blank?
        @name_providers = [
          NameProviders::ColNameProvider.new,
          NameProviders::UBioNameProvider.new,
          NameProviders::NZORNameProvider.new
        ]
      end
    end

    def to_s
      "<Ratatosk: I am Ratatosk, the Dark Squirrel of Doom!>"
    end

    #
    # Find a taxon using each of the name providers in sequence, returning the
    # first successful response.
    #
    def find(q)
      @name_providers.each do |name_provider|
        begin
          names = name_provider.find(q)
        rescue Timeout::Error => e
          # skip to next name provider if one times out
          if name_provider == @name_providers.last
            raise e
          else
            next
          end
        end
        
        # make sure names are unique on name and lexicon
        # This is sort of a duplication of the validation that should occur in
        # TaxonName, but since all the adapters hold NEW objects at this
        # point, two identical names with identical Taxon objects will both
        # save as valid, because the Taxon objects are unsaved and the
        # validation to keep taxon names unique within a lexicon and a taxon
        # will pass because the taxa are different objects from ActiveRecord's
        # point of view.  The alternative would be to ALWAYS save taxon
        # objects upon creation in the TaxonNameAdapters, but I tried to avoid
        # incurring the DB writing overhead.
        unique_names = {}
        unique_taxa = {}
        names.each do |n| 
          phylum_name = name_provider.get_phylum_for(n.taxon).name rescue nil
          unique_taxa[[n.taxon.name, phylum_name]] ||= n.taxon
          n.taxon = unique_taxa[[n.taxon.name, phylum_name]] rescue nil
          next unless n.taxon
          unique_names[[n.name, n.lexicon, n.taxon.name, phylum_name]] = n
        end
        names = unique_names.values
        
        names = names.map do |name|
          if name.taxon && 
              name.taxon.new_record? &&
              (existing_taxon = find_existing_taxon(name.taxon))
            name.taxon = existing_taxon
          end
          
          unless name.valid?
            # If the name was invalid b/c its taxon was saved first, and the
            # taxon made a TaxonName from its own scientific name already,
            # just use that scientific name
            if name.taxon.valid?
              name = if existing = TaxonName.where("name = ? AND taxon_id = ?", name.name, name.taxon_id).first
                existing
              else
                name.taxon.taxon_names.detect{|tn| tn.name == name.name}
              end
            
            # If the taxon was invalid, try to see if something similar has 
            # already been saved
            elsif existing = Taxon.where(source_identifier: name.taxon.source_identifier,
              name_provider: name.taxon.name_provider).first
              name.taxon = existing
            else
              name = nil
            end
          end
          name
        end.compact.uniq
        
        return names unless names.empty?
      end
      []
    end

    #
    # Take an ungrafted taxon and find its ancestor taxa from itself to an
    # existing taxon in our tree, saving any new members of this branch and
    # attaching it to the existing taxon (the graft point).
    #
    def graft(taxon, options = {})
      # if this is an adapter of some kind, just get the underlying Taxon
      # object. It will smooth the way with nested_set...
      taxon = taxon.taxon unless taxon.is_a? Taxon
      raise RatatoskGraftError, "Can't graft unsaved taxa" if taxon.new_record?

      graft_point, lineage = graft_point_and_lineage(taxon, options)

      # Return an empty lineage if this has already been grafted
      return [] if lineage.blank?
      return [] if lineage.first.parent == lineage.last
      return [] if lineage.size == 1 && lineage.first.grafted?
      return [] if lineage.size == 1 && lineage.first == graft_point

      # For each new taxon (starting with the highest), move it to the graft
      # point, moving the point as we walk along the branch
      lineage.reverse_each do |new_taxon|
        new_taxon = new_taxon.taxon unless new_taxon.is_a? Taxon
        new_taxon.save if new_taxon.new_record? # can't move new nodes
        unless new_taxon.valid?
          msg = "Failed to graft #{new_taxon} because it was invalid: " + 
            new_taxon.errors.full_messages.join(', ')
          new_taxon.logger.error "[ERROR] #{msg}" if new_taxon.logger
          raise RatatoskGraftError, msg
        end
        new_taxon.set_scientific_taxon_name
        new_taxon.move_to_child_of(graft_point)
        unless new_taxon.valid?
          if new_taxon.errors[:ancestry].to_s =~ /locked/
            msg = "it failed to graft to #{graft_point.name}, which "
            msg += taxon.locked? ? "is locked. " : "descends from a locked taxon. "
            msg += "Please merge or delete, or edit and add it if it's legit."
            f = new_taxon.flags.build(:flag => msg) 
            unless f.save
              puts "Failed to save flag: #{f.errors.full_messages.to_sentence}"
            end
          else
            raise RatatoskGraftError, "New taxon had errors: #{new_taxon.errors.full_messages.to_sentence}"
          end
        end
        graft_point = new_taxon
      end

      lineage
    end
    
    def graft_point_and_lineage(taxon, options = {})
      # Try a simple polynom lookup first
      if parent = polynom_parent(taxon.name, options)
        return [parent, [taxon]]
      end
      
      # retrieve the Name Provider used to find this taxon
      name_provider = @name_providers.detect do |np|
        np.class.name == taxon.name_provider || np.class.name.split('::').last == taxon.name_provider
      end
      name_provider ||= NameProviders.const_get(taxon.name_provider).new rescue nil
      lineage = if name_provider.nil?
        [taxon]
      else
        begin
          name_provider.get_lineage_for(taxon)
        rescue NameProviderError => e
          raise RatatoskGraftError, e.message
        end
      end
      
      # This basically means the name provider wasn't able to find a lineage
      if lineage.size == 1 && lineage.first.rank_level < Taxon::RANK_LEVELS['phylum']
        # try retrieving an external parent based on a polynom, e.g. if the
        # name is Homo sapiens and there's no Homo taxon, try to get Homo from
        # the NameProvider
        if parent = polynom_parent(taxon.name, options.merge(:external_parent => true))
          taxon_phylum = name_provider.get_phylum_for(taxon) if name_provider
          if parent.phylum.blank? || taxon_phylum.blank? || parent.phylum.name == taxon_phylum.name
            return [parent, [taxon]]
          end
        end
        return [lineage.first, lineage]
      end
      
      # Set the point on the tree to which we will graft, default is root
      get_graft_point_for(lineage)
    end
    
    def get_graft_point_for(lineage)
      name_provider = NameProviders.const_get(lineage.last.name_provider).new
      new_lineage = []
      graft_point = nil
      
      # Exclude non-preferred ranks from lineage
      # Note: this coupling to the iNat Taxon class isn't ideal, and should
      # be refactored if this plugin ever needs to be separated.
      lineage = lineage.select do |tn|
        taxon = tn.is_a?(Taxon) ? tn : tn.taxon
        rank = Taxon::RANK_EQUIVALENTS[taxon.rank] || taxon.rank
        Taxon::PREFERRED_RANKS.include?(rank)
      end
      
      ancestor_phylum = name_provider.get_phylum_for(lineage.first, lineage)
      lineage.each do |ancestor|
        existing_homonyms = if ancestor.new_record?
          Taxon.where(name: ancestor.name)
        else
          Taxon.where(name: ancestor.name).where("id != ?", ancestor.id)
        end
        
        if existing_homonyms.size == 1 && 
            %w"kingdom phylum".include?(existing_homonyms.first.rank)
          graft_point = existing_homonyms.first
          lineage = new_lineage
          break
        end
        
        graft_point = existing_homonyms.select do |homonym|
          ancestor_phylum && homonym.phylum && ancestor_phylum.name == homonym.phylum.name
        end.first
        
        if graft_point
          lineage = new_lineage
          break
        end
        
        new_lineage << ancestor
      end
      graft_point ||= Taxon.find_by_name('Life') rescue Taxon.root
      [graft_point, lineage.compact]
    end
    
    def find_existing_taxon(taxon_adapter, name_provider = nil)
      name_provider ||= NameProviders.const_get(taxon_adapter.name_provider).new
      existing_phylum = if (phylum = name_provider.get_phylum_for(taxon_adapter))
        Taxon.where("lower(name) = ? AND rank = 'phylum'", phylum.name.downcase).first
      end

      if existing_phylum
        existing_phylum.descendants.where("lower(name) = ?", taxon_adapter.name.downcase).first
      else
        Taxon.where("lower(name) = ?", taxon_adapter.name.downcase).first
      end
    end
    
    protected

    #
    # Try to find the parent taxon given a polynomial name, e.g. "Homo
    # sapiens" (a binom) or "Ensatina eschscholtzii xanthoptica" (a trinom). 
    # Returns nil if none found or if not a polynom.
    #
    def polynom_parent(name, options = {})
      parent_name = if name =~ /\s+×\s+/
        name.split.first
      else
        name.split[0..-2].join(' ')
      end
      return nil if parent_name.blank?
      parent = if options[:ancestor]
        Taxon.where(options[:ancestor].descendant_conditions).where("name = ?", parent_name).first
      else
        Taxon.find_by_name(parent_name)
      end
      if parent.blank? && options[:external_parent]
        names = find(parent_name)
        if match = names.detect{|n| n.taxon.name == parent_name}
          match.save
          parent = match.taxon
          parent.graft_silently
        end
      end
      parent
    end
  end # class Ratatosk
end # module Ratatosk
