# wrappers and constants for expressing iNat records as Darwin Core fields
module DarwinCore
  
  class Taxon
    TERMS = [
      %w(identifier http://purl.org/dc/terms/identifier),
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
  
  class Occurrence

    TERMS = [
      %w(id id),
      %w(basisOfRecord http://rs.tdwg.org/dwc/terms/basisOfRecord HumanObservation),
      %w(modified http://purl.org/dc/terms/modified),
      %w(institutionCode http://rs.tdwg.org/dwc/terms/institutionCode iNaturalist),
      %w(collectionCode http://rs.tdwg.org/dwc/terms/collectionCode Observations),
      %w(datasetName http://rs.tdwg.org/dwc/terms/datasetName),
      %w(informationWithheld http://rs.tdwg.org/dwc/terms/informationWithheld),
      %w(catalogNumber http://rs.tdwg.org/dwc/terms/catalogNumber),
      %w(references http://purl.org/dc/terms/references),
      %w(occurrenceRemarks http://rs.tdwg.org/dwc/terms/occurrenceRemarks),
      %w(recordedBy http://rs.tdwg.org/dwc/terms/recordedBy),
      %w(establishmentMeans http://rs.tdwg.org/dwc/terms/establishmentMeans),
      %w(associatedMedia http://rs.tdwg.org/dwc/terms/associatedMedia),
      %w(eventDate http://rs.tdwg.org/dwc/terms/eventDate),
      %w(eventTime http://rs.tdwg.org/dwc/terms/eventTime),
      %w(verbatimEventDate http://rs.tdwg.org/dwc/terms/verbatimEventDate),
      %w(verbatimLocality http://rs.tdwg.org/dwc/terms/verbatimLocality),
      %w(decimalLatitude http://rs.tdwg.org/dwc/terms/decimalLatitude),
      %w(decimalLongitude http://rs.tdwg.org/dwc/terms/decimalLongitude),
      %w(coordinateUncertaintyInMeters http://rs.tdwg.org/dwc/terms/coordinateUncertaintyInMeters),
      %w(identificationID http://rs.tdwg.org/dwc/terms/identificationID),
      %w(dateIdentified http://rs.tdwg.org/dwc/terms/dateIdentified),
      %w(identificationRemarks http://rs.tdwg.org/dwc/terms/identificationRemarks),
      %w(taxonID http://rs.tdwg.org/dwc/terms/taxonID),
      %w(scientificName http://rs.tdwg.org/dwc/terms/scientificName),
      %w(taxonRank http://rs.tdwg.org/dwc/terms/taxonRank),
      %w(kingdom http://rs.tdwg.org/dwc/terms/kingdom),
      %w(phylum http://rs.tdwg.org/dwc/terms/phylum),
      ['class', 'http://rs.tdwg.org/dwc/terms/class', nil, 'taxon_class'],
      %w(order http://rs.tdwg.org/dwc/terms/order),
      %w(family http://rs.tdwg.org/dwc/terms/family),
      %w(genus http://rs.tdwg.org/dwc/terms/genus),
      %w(rights http://purl.org/dc/terms/rights),
      %w(rightsHolder http://purl.org/dc/terms/rightsHolder)
    ]
    TERM_NAMES = TERMS.map{|name, uri, default, method| name}
    
    # Extend observation with DwC methods.  For reasons unclear to me, url
    # methods are protected if you instantiate a view *outside* a model, but not
    # inside.  Otherwise I would just used a more traditional adapter with
    # delegation.
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

      def occurrenceID
        view.observation_url(self)
      end

      def references
        view.observation_url(self)
      end

      def basisOfRecord
        "HumanObservation"
      end

      def modified
        updated_at.iso8601
      end

      def institutionCode
        "iNaturalist"
      end

      def collectionCode
        "Observations"
      end

      def datasetName
        if quality_grade == Observation::RESEARCH_GRADE
          "iNaturalist research-grade observations"
        else
          "iNaturalist observations"
        end
      end

      def informationWithheld
        if geoprivacy_private?
          "Coordinates hidden at the request of the observer"
        elsif geoprivacy_obscured?
          "Coordinate uncertainty increased by #{Observation::M_TO_OBSCURE_THREATENED_TAXA}m at the request of the observer"
        elsif coordinates_obscured?
          "Coordinate uncertainty increased by #{Observation::M_TO_OBSCURE_THREATENED_TAXA}m to protect threatened taxon"
        else
          nil
        end
      end

      def catalogNumber
        id
      end

      def occurrenceRemarks
        dwc_filter_text(description) unless description.blank?
      end


      def recordedBy
        user.name.blank? ? user.login : user.name
      end

      def establishmentMeans
        score = quality_metric_score(QualityMetric::WILD)
        score && score < 0.5 ? "cultivated" : "wild"
      end

      def associatedMedia
        photo_urls = photos.map{|p| [p.medium_url, p.native_page_url]}.flatten.compact
        photo_urls.join(', ')
      end

      def eventDate
        time_observed_at ? datetime.iso8601 : observed_on.to_s
      end

      def eventTime
        time_observed_at ? time_observed_at.iso8601.sub(/^.*T/, '') : nil
      end

      def verbatimEventDate
        observed_on_string unless observed_on_string.blank?
      end

      def verbatimLocality
        place_guess unless place_guess.blank?
      end

      def decimalLatitude
        latitude.to_f unless latitude.blank?
      end

      def decimalLongitude
        longitude.to_f unless longitude.blank?
      end

      def coordinateUncertaintyInMeters
        if coordinates_obscured?
          positional_accuracy.to_i + Observation::M_TO_OBSCURE_THREATENED_TAXA
        elsif !positional_accuracy.blank?
          positional_accuracy
        end
      end

      def identificationID
        owners_identification.try(:id)
      end

      def dateIdentified
        owners_identification.updated_at.iso8601 if owners_identification
      end

      def identificationRemarks
        dwc_filter_text(owners_identification.body) if owners_identification
      end

      def taxonID
        taxon_id
      end

      def scientificName
        taxon.name if taxon
      end

      def taxonRank
        taxon.rank if taxon
      end

      def kingdom
        taxon.kingdom.try(:name) if taxon
      end

      def phylum
        taxon.phylum.try(:name) if taxon
      end

      def taxon_class
        taxon.find_class.try(:name) if taxon
      end

      def order
        taxon.order.try(:name) if taxon
      end

      def family
        taxon.family.try(:name) if taxon
      end

      def genus
        taxon.genus.try(:name) if taxon
      end


      def rights
        s = "Copyright #{rightsHolder}"
        unless license.blank?
          s += ", licensed under a #{license_name} license: #{view.url_for_license(license)}"
        end
        s
      end

      def rightsHolder
        user.name.blank? ? user.login : user.name
      end

      protected

      def dwc_filter_text(s)
        s.to_s.gsub(/\r\n|\n/, " ")
      end
    end
  end
end
