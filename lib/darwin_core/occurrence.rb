# frozen_string_literal: true

# rubocop:disable Naming/MethodName

module DarwinCore
  class Occurrence
    # Terms are tuples of (
    #   term name,
    #   term URI,
    #   default value,
    #   Observation method to call to get the value if it differs from the term name,
    #   vocabulary URI
    # )
    # The easiest way to find new term URI's is to use
    # http://tools.gbif.org/dwca-assistant/. Vocabularies that GBIF understands
    # are at https://rs.gbif.org/vocabulary, though it's probably only best to
    # specify one if we're actually adhering to it.
    ANNOTATION_TERMS = [
      ["sex", "http://rs.tdwg.org/dwc/terms/sex", nil, "gbif_sex", "http://rs.gbif.org/vocabulary/gbif/sex"],
      ["lifeStage", "http://rs.tdwg.org/dwc/terms/lifeStage", nil, "gbif_lifeStage", "http://rs.gbif.org/vocabulary/gbif/life_stage"],
      ["reproductiveCondition", "http://rs.tdwg.org/dwc/terms/reproductiveCondition", nil],
      ["vitality", "http://rs.tdwg.org/dwc/terms/vitality", nil],
      ["dynamicProperties", "http://rs.tdwg.org/dwc/terms/dynamicProperties", nil]
    ].freeze
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
      %w(recordedBy http://rs.tdwg.org/dwc/terms/recordedBy),
      %w(recordedByID http://rs.tdwg.org/dwc/terms/recordedByID),
      %w(identifiedBy http://rs.tdwg.org/dwc/terms/identifiedBy),
      %w(identifiedByID http://rs.tdwg.org/dwc/terms/identifiedByID),
      %w(captive https://www.inaturalist.org/terminology/captive_cultivated),
      %w(eventDate http://rs.tdwg.org/dwc/terms/eventDate),
      %w(eventTime http://rs.tdwg.org/dwc/terms/eventTime),
      %w(verbatimEventDate http://rs.tdwg.org/dwc/terms/verbatimEventDate),
      %w(verbatimLocality http://rs.tdwg.org/dwc/terms/verbatimLocality),
      %w(decimalLatitude http://rs.tdwg.org/dwc/terms/decimalLatitude),
      %w(decimalLongitude http://rs.tdwg.org/dwc/terms/decimalLongitude),
      %w(coordinateUncertaintyInMeters http://rs.tdwg.org/dwc/terms/coordinateUncertaintyInMeters),
      %w(geodeticDatum http://rs.tdwg.org/dwc/terms/geodeticDatum EPSG:4326),
      %w(countryCode http://rs.tdwg.org/dwc/terms/countryCode),
      %w(stateProvince http://rs.tdwg.org/dwc/terms/stateProvince),
      %w(identificationID http://rs.tdwg.org/dwc/terms/identificationID),
      %w(dateIdentified http://rs.tdwg.org/dwc/terms/dateIdentified),
      %w(identificationRemarks http://rs.tdwg.org/dwc/terms/identificationRemarks),
      %w(taxonID http://rs.tdwg.org/dwc/terms/taxonID),
      %w(scientificName http://rs.tdwg.org/dwc/terms/scientificName),
      %w(taxonRank http://rs.tdwg.org/dwc/terms/taxonRank),
      %w(kingdom http://rs.tdwg.org/dwc/terms/kingdom),
      %w(phylum http://rs.tdwg.org/dwc/terms/phylum),
      ["class", "http://rs.tdwg.org/dwc/terms/class", nil, "taxon_class"],
      %w(order http://rs.tdwg.org/dwc/terms/order),
      %w(family http://rs.tdwg.org/dwc/terms/family),
      %w(genus http://rs.tdwg.org/dwc/terms/genus),
      ["license", "http://purl.org/dc/terms/license", nil, "dwc_license"],
      %w(rightsHolder http://purl.org/dc/terms/rightsHolder),
      %w(inaturalistLogin http://xmlns.com/foaf/0.1/nick),
      %w(publishingCountry http://rs.gbif.org/terms/1.0/publishingCountry),
      %w(projectId http://rs.gbif.org/terms/1.0/projectId)
    ] + ANNOTATION_TERMS
    cattr_accessor :annotation_controlled_attributes do
      {}
    end
    TERM_NAMES = TERMS.map {| name, _uri, _default, _method | name }

    ALA_EXTRA_TERMS = [
      %w(identificationVerificationStatus http://rs.tdwg.org/dwc/terms/identificationVerificationStatus),
      %w(numIdentificationAgreements https://www.inaturalist.org/terminology/num_identification_agreements),
      %w(numIdentificationDisagreements https://www.inaturalist.org/terminology/num_identification_disagreements),
      %w(positioningDevice https://www.inaturalist.org/terminology/positioning_device),
      %w(positioningMethod https://www.inaturalist.org/terminology/positioning_method)
    ].freeze

    OTHER_CATALOGUE_NUMBERS_TERM = %w(
      otherCatalogueNumbers http://rs.tdwg.org/dwc/terms/otherCatalogNumbers
    ).freeze

    COUNTY_TERM = %w(
      county http://rs.tdwg.org/dwc/terms/county
    ).freeze

    PUBLIC_COORDINATES_TERMS = [
      %w(publicLatitude https://www.inaturalist.org/terminology/latitude),
      %w(publicLongitude https://www.inaturalist.org/terminology/longitude)
    ].freeze

    GBIF_LIFE_STAGES = %w(
      adult
      agamont
      ammocoete
      bipinnaria
      blastomere
      calf
      caterpillar
      chick
      eft
      egg
      elver
      embryo
      fawn
      foal
      fry
      gamete
      gametophyte
      gamont
      glochidium
      grub
      hatchling
      imago
      infant
      juvenile
      kit
      kitten
      larva
      larvae
      leptocephalus
      maggot
      nauplius
      nymph
      ovule
      ovum
      planula
      polewig
      pollen
      polliwig
      polliwog
      pollywog
      polwig
      protonema
      pup
      pupa
      puppe
      seed
      seedling
      sperm
      spore
      sporophyte
      tadpole
      trochophore
      veliger
      whelp
      wriggler
      zoea
      zygote
    ).freeze

    ANNOTATION_CONTROLLED_TERM_MAPPING = {
      sex: "Sex",
      lifeStage: "Life Stage",
      reproductiveCondition: "Flowers and Fruits",
      vitality: "Alive or Dead"
    }.freeze

    ANNOTATION_ATTRIBUTES_FOR_DYNAMIC_PROPERTIES = [
      "Evidence of Presence",
      "Leaves"
    ].freeze

    # Extend observation with DwC methods.  For reasons unclear to me, url
    # methods are protected if you instantiate a view *outside* a model, but not
    # inside.  Otherwise I would just used a more traditional adapter with
    # delegation.
    def self.adapt( record, options = {} )
      record.extend( InstanceMethods )
      record.extend( DarwinCore::Helpers )
      record.set_view( options[:view] )
      record.set_show_private_coordinates( options[:private_coordinates] )
      record.dwc_use_community_taxon if options[:community_taxon]
      record
    end

    def self.term_names( terms )
      terms.map {| name, _uri, _default, _method | name }
    end

    module InstanceMethods
      def view
        @view ||= FakeView
      end

      def set_view( view )
        @view = view
      end

      def set_show_private_coordinates( show_private_coordinates )
        @show_private_coordinates = show_private_coordinates
      end

      def dwc_use_community_taxon
        @dwc_use_community_taxon = true
      end

      def occurrenceID
        uri
      end

      def references
        view.observation_url( id )
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
          if @show_private_coordinates
            "Coordinates included here but private on iNaturalist"
          else
            "Coordinates hidden at the request of the observer"
          end
        elsif geoprivacy_obscured?
          if @show_private_coordinates
            "Coordinates not obscured here but publicly obscured on iNaturalist"
          else
            "Coordinate uncertainty increased to #{public_positional_accuracy}m at the request of the observer"
          end
        elsif coordinates_obscured?
          if @show_private_coordinates
            "Coordinates not obscured here but publicly obscured on iNaturalist due to taxon geoprivacy"
          else
            "Coordinate uncertainty increased to #{public_positional_accuracy}m to protect threatened taxon"
          end
        end
      end

      def catalogNumber
        id
      end

      def occurrenceRemarks
        dwc_filter_text( description ) unless description.blank?
      end

      def recordedBy
        user.name.blank? ? user.login : user.name
      end

      def inaturalistLogin
        user.login
      end

      def recordedByID
        orcid_id = user.provider_authorizations.detect {| pa | pa.provider_name == "orcid" }.try( :provider_uid )
        return unless orcid_id

        "https://orcid.org/#{orcid_id}"
      end

      def identifiedBy
        return unless ( first_improving = first_improving_identification )

        first_improving.user.name.blank? ? first_improving.user.login : first_improving.user.name
      end

      def identifiedByID
        return unless ( first_improving = first_improving_identification )

        orcid_id = first_improving.user.provider_authorizations.detect do | pa |
          pa.provider_name == "orcid"
        end.try( :provider_uid )
        return if orcid_id.blank?

        "https://orcid.org/#{orcid_id}"
      end

      # As noted in https://github.com/gbif/occurrence/issues/89, identifiedBy
      # and identifiedByID are primarily meant to provide attribution to the
      # person who first provided the "correct" identification and not
      # necessarily to track all people who may have agreed with that
      # identification, sp we are only including the person who added the first
      # improving identification that matches the observation taxon
      def first_improving_identification
        return unless dwc_taxon

        taxon_id = dwc_taxon.id
        idents = identifications.select( &:current? ).sort_by( &:id )
        idents.detect {| i | i.taxon_id == taxon_id && i.category == Identification::IMPROVING }
      end

      def captive
        score = quality_metric_score( QualityMetric::WILD )
        score && score < 0.5 ? "cultivated" : "wild"
      end

      def eventDate
        time_observed_at ? datetime.iso8601 : observed_on.to_s
      end

      def eventTime
        time_observed_at ? datetime.iso8601.sub( /^.*T/, "" ) : nil
      end

      def verbatimEventDate
        dwc_filter_text( observed_on_string ) unless observed_on_string.blank?
      end

      def verbatimLocality
        if @show_private_coordinates
          dwc_filter_text( private_place_guess || place_guess ) unless place_guess.blank?
        else
          dwc_filter_text( place_guess ) unless place_guess.blank?
        end
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
        if @show_private_coordinates
          positional_accuracy
        else
          public_positional_accuracy
        end
      end

      def geodeticDatum
        "EPSG:4326"
      end

      def countryCode
        return if latitude.blank?

        observations_places.map( &:place ).compact.detect {| p | p.admin_level == Place::COUNTRY_LEVEL }.try( :code )
      end

      def stateProvince
        return if latitude.blank?

        observations_places.map( &:place ).compact.detect {| p | p.admin_level == Place::STATE_LEVEL }.try( :name )
      end

      def county
        return if latitude.blank?

        place_county_name
      end

      def identificationID
        first_improving_identification.try( :id )
      end

      def dateIdentified
        first_improving_identification&.created_at&.iso8601
      end

      def identificationRemarks
        dwc_filter_text( first_improving_identification.body ) if first_improving_identification
      end

      def taxonID
        dwc_taxon.try( :id )
      end

      def scientificName
        dwc_taxon.try( :name )
      end

      def taxonRank
        dwc_taxon.try( :rank )
      end

      def kingdom
        @ranked_ancestors ?
          @ranked_ancestors.dig( :kingdom_name ) : dwc_taxon.try( :kingdom_name )
      end

      def phylum
        @ranked_ancestors ?
          @ranked_ancestors.dig( :phylum_name ) : dwc_taxon.try( :phylum_name )
      end

      def taxon_class
        @ranked_ancestors ?
          @ranked_ancestors.dig( :class_name ) : dwc_taxon.try( :taxonomic_class_name )
      end

      def order
        @ranked_ancestors ?
          @ranked_ancestors.dig( :order_name ) : dwc_taxon.try( :taxonomic_order_name )
      end

      def family
        @ranked_ancestors ?
          @ranked_ancestors.dig( :family_name ) : dwc_taxon.try( :family_name )
      end

      def genus
        @ranked_ancestors ?
          @ranked_ancestors.dig( :genus_name ) : dwc_taxon.try( :genus_name )
      end

      def dwc_license
        FakeView.url_for_license( license ) || license
      end

      def rightsHolder
        user.name.blank? ? user.login : user.name
      end

      def dwc_taxon
        @dwc_use_community_taxon ? community_taxon : taxon
      end

      def set_ranked_ancestors( ranked_ancestors )
        @ranked_ancestors = ranked_ancestors
      end

      def identificationVerificationStatus
        quality_grade
      end

      def numIdentificationAgreements
        num_identification_agreements
      end

      def numIdentificationDisagreements
        num_identification_disagreements
      end

      def positioningDevice
        positioning_device
      end

      def positioningMethod
        positioning_method
      end

      # Attempting to match terms used on iNat to https://rs.gbif.org/vocabulary/gbif/sex.xml
      def gbif_sex
        winning_value = winning_annotation_value_for_term( "sex" )
        case winning_value
        when "cannot be determined"
          "undetermined"
        else
          winning_value
        end
      end

      def gbif_lifeStage
        winning_value = winning_annotation_value_for_term( "lifeStage" )
        return winning_value if GBIF_LIFE_STAGES.include?( winning_value )

        nil
      end

      def reproductiveCondition
        v = winning_annotations_for_term( "reproductiveCondition" ).map do | a |
          a.controlled_value.label.downcase
        end.join( "|" )
        v == "cannot be determined" ? nil : v
      end

      # dynamicProperties can be used to list additional measurements, facts, etc in a format
      # such as JSON. Currently the values for selected annotation categories, those in
      # ANNOTATION_ATTRIBUTES_FOR_DYNAMIC_PROPERTIES, are included as a JSON string
      def dynamicProperties
        dynamic_properties = {}
        ANNOTATION_ATTRIBUTES_FOR_DYNAMIC_PROPERTIES.each do | label |
          values = winning_annotations_for_term( label ).map do | annotation |
            annotation.controlled_value.label.downcase
          end
          next if values.empty?

          dynamic_property_label = label.downcase.tr( " ", "_" ).camelize( :lower )
          dynamic_properties[dynamic_property_label] = values.size == 1 ? values.first : values.sort
        end
        return nil if dynamic_properties.blank?

        dynamic_properties.to_json
      end

      def vitality
        winning_value = winning_annotation_value_for_term( "vitality" )
        case winning_value
        when "cannot be determined"
          "undetermined"
        else
          winning_value
        end
      end

      def otherCatalogueNumbers
        uuid
      end

      def winning_annotations_for_term( term, options = {} )
        return [] if annotations.blank?

        inat_term = ANNOTATION_CONTROLLED_TERM_MAPPING[term.to_sym] || term
        DarwinCore::Occurrence.annotation_controlled_attributes[term] ||= ControlledTerm.
          joins( :labels ).
          where( is_value: false, active: true ).
          where( "LOWER(controlled_term_labels.label) = ?", inat_term.downcase ).
          first
        controlled_attribute = DarwinCore::Occurrence.annotation_controlled_attributes[term]
        return [] unless controlled_attribute

        annotations.select {| a | a.controlled_attribute_id == controlled_attribute.id && a.vote_score >= 0 }
      end

      def winning_annotation_value_for_term( term, options = {} )
        winning_anno = winning_annotations_for_term( term, options ).first
        return unless winning_anno

        winning_anno.controlled_value.label.downcase
      end

      def publishingCountry
        return unless site&.place&.code

        return unless site.place.admin_level == Place::COUNTRY_LEVEL

        return unless site.place.code.size == 2

        site.place.code.upcase
      end

      def projectId
        projects.map {| project | FakeView.project_url( project ) }.join( "|" )
      end

      # public latitude for when decimalLatitude contains the private latitude
      def publicLatitude
        return unless @show_private_coordinates
        return if private_latitude.blank?
        return if latitude.blank?

        latitude.to_f
      end

      # public longitude for when decimalLongitude contains the private longitude
      def publicLongitude
        return unless @show_private_coordinates
        return if private_longitude.blank?
        return if longitude.blank?

        longitude.to_f
      end
    end
  end
end
# rubocop:enable Naming/MethodName
