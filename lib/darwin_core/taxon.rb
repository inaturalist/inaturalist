module DarwinCore
  class Taxon
    TERMS = [
      %w(id id),
      %w(taxonID http://rs.tdwg.org/dwc/terms/taxonID),
      %w(identifier http://purl.org/dc/terms/identifier),
      %w(parentNameUsageID http://rs.tdwg.org/dwc/terms/parentNameUsageID),
      %w(kingdom http://rs.tdwg.org/dwc/terms/kingdom),
      %w(phylum http://rs.tdwg.org/dwc/terms/phylum),
      ['class', 'http://rs.tdwg.org/dwc/terms/class', nil, 'find_class_name'],
      %w(order http://rs.tdwg.org/dwc/terms/order),
      %w(family http://rs.tdwg.org/dwc/terms/family),
      %w(genus  http://rs.tdwg.org/dwc/terms/genus),
      %w(specificEpithet http://rs.tdwg.org/dwc/terms/specificEpithet),
      %w(infraspecificEpithet http://rs.tdwg.org/dwc/terms/infraspecificEpithet),
      %w(modified http://purl.org/dc/terms/modified),
      %w(scientificName http://rs.tdwg.org/dwc/terms/scientificName),
      %w(taxonRank http://rs.tdwg.org/dwc/terms/taxonRank),
      %w(references http://purl.org/dc/terms/references)
    ]
    TERM_NAMES = TERMS.map{|name, uri, default, method| name}
    
    @kingdom_cache = {}
    @phylum_cache = {}
    @class_cache = {}
    @order_cache = {}
    @family_cache = {}
    @genus_cache = {}
    
    def self.adapt(record, options = {})
      record.extend(InstanceMethods)
      record.set_view(options[:view])
      record
    end

    module InstanceMethods
      def view
        @view ||= FakeView
      end

      def set_view(view)
        @view = view
      end
      
      def identifier
        view.taxon_url(self.id)
      end
      
      def taxonID
        identifier
      end

      def parentNameUsageID
        view.taxon_url(parent_id) if parent_id
      end
      
      def specificEpithet
        return nil unless species_or_lower?
        name.split[1]
      end
      
      def infraspecificEpithet
        return nil unless rank_level < ::Taxon::SPECIES_LEVEL
        name.split[2]
      end
      
      def modified
        updated_at.iso8601
      end
      
      def scientificName
        name
      end
      
      def taxonRank
        rank
      end
      
      def references
        source_url || source.try(:url)
      end
      
      def cached_ancestor(rank)
        return nil if rank_level > ::Taxon.const_get("#{rank.to_s.upcase}_LEVEL")
        cache = DarwinCore::Taxon.instance_variable_get("@#{rank}_cache")
        t = nil
        ancestor_ids.each do |aid|
          break if t = cache[aid]
        end
        unless t
          if ancestor = send("find_#{rank}")
            t = ancestor.name
            cache[ancestor.id] = t
          end
        end
        t
      end
      
      def kingdom
        cached_ancestor(:kingdom)
      end
      
      def phylum
        cached_ancestor(:phylum)
      end
      
      def find_class_name
        cached_ancestor(:class)
      end
      
      def order
        cached_ancestor(:order)
      end
      
      def family
        cached_ancestor(:family)
      end
      
      def genus
        if rank_level > ::Taxon::GENUS_LEVEL
          find_genus.try(:name)
        elsif rank == ::Taxon::GENUS
          name
        else
          name.split.first
        end
      end
    end
  end
end
