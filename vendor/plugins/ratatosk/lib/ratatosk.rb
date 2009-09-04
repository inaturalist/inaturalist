#
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

require 'ratatosk/name_providers'

class RatatoskGraftError < StandardError; end

module Ratatosk
  
  class <<self
    #
    # Alias for Ratatosk::Ratatosk#find
    #
    def find(name)
      @ratatosk ||= Ratatosk.new
      @ratatosk.find(name)
    end
    
    #
    # Alias for Ratatosk::Ratatosk#graft
    #
    def graft(taxon)
      @ratatosk ||= Ratatosk.new
      @ratatosk.graft(taxon)
    end
  end
  
  class Ratatosk
    attr_reader :name_providers

    def initialize(params = {})
      @name_providers = params[:name_providers]
      @name_providers ||= [
        NameProviders::ColNameProvider.new,
        NameProviders::UBioNameProvider.new
      ]
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
        
        # puts "[DEBUG] Found names: #{names.map(&:name).join(', ')}"
        
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
          # puts "[DEBUG] #{n.name}'s phylum: #{name_provider.get_phylum_for(n.taxon).name}"
          phylum_name = name_provider.get_phylum_for(n.taxon).name rescue nil
          unique_taxa[[n.taxon.name, phylum_name]] ||= n.taxon
          n.taxon = unique_taxa[[n.taxon.name, phylum_name]]
          unique_names[[n.name, n.lexicon, n.taxon.name, phylum_name]] = n
        end
        names = unique_names.values
        
        
        # puts "[DEBUG] Unique names: #{names.map(&:name).join(', ')}"
        
        names = names.map do |name|
          if existing_taxon = find_existing_taxon(name.taxon)
            name.taxon = existing_taxon
          end
          
          unless name.valid?
            # If the name was invalid b/c its taxon was saved first, and the
            # taxon made a TaxonName from its own scientific name already,
            # just use that scientific name
            if name.taxon.valid?
              name = name.taxon.taxon_names.find(:first, 
                :conditions => {:name => name.name})
            
            # If the taxon was invalid, try to see if something similar has 
            # already been saved
            elsif existing = Taxon.find(:first, :conditions => [
                "source_identifier = ? AND name_provider = ?",
                name.taxon.source_identifier,
                name.taxon.name_provider
              ])
              name.taxon = existing
            else
              name = nil
            end
          end
          name
        end.compact.uniq
        
        # puts "[DEBUG] Returning names: #{names.map(&:name).join(', ')}"
        return names unless names.empty?
      end
      []
    end

    #
    # Take an ungrafted taxon and find its ancestor taxa from itself to an
    # existing taxon in our tree, saving any new members of this branch and
    # attaching it to the existing taxon (the graft point).
    #
    def graft(taxon)
      # puts "[DEBUG] Grafting #{taxon}..."
      # if this is an adapter of some kind, just get the underlying Taxon
      # object. It will smooth the way with nested_set...
      taxon = taxon.taxon unless taxon.is_a? Taxon
            
      raise RatatoskGraftError, 
        "Can't graft unsaved taxa" if taxon.new_record?

      # retrieve the Name Provider used to find this taxon
      name_provider = @name_providers.select do |name_provider|
        name_provider.class.name == taxon.name_provider or
          name_provider.class.name.split('::').last == taxon.name_provider
      end.first
      name_provider ||= NameProviders.const_get(taxon.name_provider).new

      if name_provider.nil?
        raise RatatoskGraftError, 
          "Can't graft a taxon without a name provider"
      end

      # get the lineage of this taxon's ancestors
      if parent = polynom_parent(taxon.name)
        # lineage = [taxon, parent]
        lineage = [taxon]
        graft_point = parent
      else
        begin
          lineage = name_provider.get_lineage_for(taxon)
        rescue NameProviderError => e
          raise RatatoskGraftError, e.message
        end
        
        # Set the point on the tree to which we will graft, default is root
        graft_point, lineage = get_graft_point_for(lineage)
      end

      # Return an empty lineage if this has already been grafted
      return [] if lineage.first.parent == lineage.last
      return [] if lineage.size == 1 && lineage.first.grafted?

      # puts "[DEBUG] Grafting [#{lineage.map(&:to_s).join(', ')}] to #{graft_point}..."

      # For each new taxon (starting with the highest), move it to the graft
      # point, moving the point as we walk along the branch
      lineage.reverse_each do |ancestor|        
        ancestor = ancestor.taxon unless ancestor.is_a? Taxon
        ancestor.save if ancestor.new_record? # can't move new nodes
        unless ancestor.valid?
          msg = "Failed to graft #{ancestor} because it was invalid: " + 
            ancestor.errors.full_messages.join(', ')
          ancestor.logger.error "[ERROR] #{msg}"
          raise RatatoskGraftError, msg
        end
        ancestor.set_scientific_taxon_name
        ancestor.move_to_child_of(graft_point)
        graft_point = ancestor
      end

      lineage
    end
    
    def get_graft_point_for(lineage)
      name_provider = NameProviders.const_get(lineage.last.name_provider).new
      new_lineage = []
      graft_point = nil
      ancestor_phylum = name_provider.get_phylum_for(lineage.first, lineage)
      lineage.each do |ancestor|
        # puts "\t[DEBUG] Inspecting ancestor: #{ancestor}"
        
        if ancestor.new_record?
          existing_homonyms = Taxon.all(:conditions => ["name = ?", ancestor.name])
        else
          existing_homonyms = Taxon.all(:conditions => ["id != ? AND name = ?", ancestor.id, ancestor.name])
        end
        
        # puts "\t\t[DEBUG] Found homonyms: #{existing_homonyms.join(', ')}"
        
        if existing_homonyms.size == 1 && 
            %w"kingdom phylum".include?(existing_homonyms.first.rank)
          graft_point = existing_homonyms.first
          lineage = new_lineage
          # puts "\t\t\t[DEBUG] Found a homonymous kingdom/phylum: #{graft_point}"
          break
        end
        
        graft_point = existing_homonyms.select do |homonym|
          ancestor_phylum && homonym.phylum && ancestor_phylum.name == homonym.phylum.name
        end.first
        
        if graft_point
          # puts "\t\t\t[DEBUG] Found a homonymous taxon: #{graft_point}"
          lineage = new_lineage
          break
        end
        
        new_lineage << ancestor
      end
      # puts "\t\t[DEBUG] GAARRGGHH graft_point pre default: #{graft_point}"
      graft_point ||= Taxon.find_by_name('Life') rescue Taxon.root
      [graft_point, lineage.compact]
    end
    
    def find_existing_taxon(taxon_adapter, name_provider = nil)
      # puts "[DEBUG] Looking for an existing taxon"
      name_provider ||= NameProviders.const_get(taxon_adapter.name_provider).new
      if phylum = name_provider.get_phylum_for(taxon_adapter)
        existing_phylum = Taxon.find(:first, :conditions => [
          "name = ? AND rank = 'phylum'", phylum.name
        ])
      else
        existing_phylum = nil
      end

      existing_taxon = nil
      if existing_phylum
        # puts "[DEBUG] Found existing phylum: #{existing_phylum}"
        existing_taxon = existing_phylum.descendants.first(
          :conditions => ["name = ?", taxon_adapter.name])
      else
        existing_taxon = Taxon.first(
          :conditions => ["name = ?", taxon_adapter.name])
      end

      # puts "[DEBUG] Found existing taxon: #{existing_taxon}"

      existing_taxon
    end
    
    protected

    #
    # Try to find the parent taxon given a polynomial name, e.g. "Homo
    # sapiens" (a binom) or "Ensatina eschscholtzii xanthoptica" (a trinom). 
    # Returns nil if none found or if not a polynom.
    #
    def polynom_parent(name)
      parent = nil
      parts = name.split
      while parts.size > 1
        parts.pop
        break if parent = Taxon.find_by_name(parts.join(' '))
      end
      parent
    end
  end # class Ratatosk
end # module Ratatosk
