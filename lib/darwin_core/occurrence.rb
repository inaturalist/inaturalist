module DarwinCore
  class Occurrence

    TERMS = [
      %w(id id),
      %w(occurrenceID http://rs.tdwg.org/dwc/terms/occurrenceID),
      %w(basisOfRecord http://rs.tdwg.org/dwc/terms/basisOfRecord HumanObservation),
      %w(modified http://purl.org/dc/terms/modified),
      %w(institutionCode http://rs.tdwg.org/dwc/terms/institutionCode iNaturalist),
      %w(collectionCode http://rs.tdwg.org/dwc/terms/collectionCode Observations),
      %w(datasetName http://rs.tdwg.org/dwc/terms/datasetName),
      %w(informationWithheld http://rs.tdwg.org/dwc/terms/informationWithheld),
      %w(catalogNumber http://rs.tdwg.org/dwc/terms/catalogNumber),
      %w(references http://purl.org/dc/terms/references),
      %w(occurrenceRemarks http://rs.tdwg.org/dwc/terms/occurrenceRemarks),
      %w(occurrenceDetails http://rs.tdwg.org/dwc/terms/occurrenceDetails),
      %w(recordedBy http://rs.tdwg.org/dwc/terms/recordedBy),
      %w(establishmentMeans http://rs.tdwg.org/dwc/terms/establishmentMeans),
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
      ['license', 'http://purl.org/dc/terms/license', nil, 'dwc_license'],
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
      record.set_show_private_coordinates(options[:private_coordinates])
      record
    end

    module InstanceMethods
      def view
        @view ||= FakeView
      end

      def set_view(view)
        @view = view
      end

      def set_show_private_coordinates(show_private_coordinates)
        @show_private_coordinates = show_private_coordinates
      end

      def occurrenceID
        uri
      end

      def references
        view.observation_url(id)
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

      def occurrenceDetails
        uri
      end

      def recordedBy
        user.name.blank? ? user.login : user.name
      end

      def establishmentMeans
        score = quality_metric_score(QualityMetric::WILD)
        score && score < 0.5 ? "cultivated" : "wild"
      end

      def eventDate
        time_observed_at ? datetime.iso8601 : observed_on.to_s
      end

      def eventTime
        time_observed_at ? time_observed_at.iso8601.sub(/^.*T/, '') : nil
      end

      def verbatimEventDate
        dwc_filter_text(observed_on_string) unless observed_on_string.blank?
      end

      def verbatimLocality
        dwc_filter_text(place_guess) unless place_guess.blank?
      end

      def decimalLatitude
        if @show_private_coordinates
          if private_latitude.blank?
            latitude.to_f unless latitude.blank?
          else
            private_latitude.to_f
          end
        else
          latitude.to_f unless latitude.blank?
        end
      end

      def decimalLongitude
        # longitude.to_f unless longitude.blank?
        if @show_private_coordinates
          if private_longitude.blank?
            longitude.to_f unless longitude.blank?
          else
            private_longitude.to_f
          end
        else
          longitude.to_f unless longitude.blank?
        end
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
        taxon.kingdom_name if taxon
      end

      def phylum
        taxon.phylum_name if taxon
      end

      def taxon_class
        taxon.taxonomic_class_name if taxon
      end

      def order
        taxon.taxonomic_order_name if taxon
      end

      def family
        taxon.family_name if taxon
      end

      def genus
        taxon.genus_name if taxon
      end

      def dwc_license
        FakeView.url_for_license( license ) || license
      end

      def rights
        FakeView.strip_tags( FakeView.rights( self ) )
      end

      def rightsHolder
        user.name.blank? ? user.login : user.name
      end

      protected

      def dwc_filter_text(s)
        s.to_s.gsub(/\r\n|\n|\t/, " ")
      end
    end
  end
  
end
