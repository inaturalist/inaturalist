# wrappers and constants for expressing iNat records as Darwin Core fields
class DarwinCore
  
  DARWIN_CORE_TERMS = [
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
    %w(rights http://purl.org/dc/terms/rights),
    %w(rightsHolder http://purl.org/dc/terms/rightsHolder)
  ]
  DARWIN_CORE_TERM_NAMES = DARWIN_CORE_TERMS.map{|name, uri| name}
  
  class FakeView < ActionView::Base
    include ActionView::Helpers::TagHelper
    include ActionView::Helpers::AssetTagHelper
    include ActionView::Helpers::UrlHelper
    include ActionController::UrlWriter
    include ApplicationHelper

    @@default_url_options = {:host => APP_CONFIG[:site_url].sub("http://", '')}

    def initialize
      super
      self.view_paths = [File.join(RAILS_ROOT, 'app/views')]
    end
  end
  
  # Extend observation with DwC methods.  For reasons unclear to me, url
  # methods are protected if you instantiate a view *outside* a model, but not
  # inside.  Otherwise I would just used a more traditional adapter with
  # delegation.
  def self.adapt(observation, options = {})
    observation.extend(InstanceMethods)
    observation.set_view(options[:view])
    observation
  end
  
  module InstanceMethods
    def view
      @view ||= FakeView.new
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
      photo_urls = photos.map{|p| [p.original_url, p.native_page_url]}.flatten.compact
      photo_urls.join(',')
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

    def rights
      s = "Copyright #{rightsHolder}"
      unless license.blank?
        s += ", licensed under a #{license_name} license: #{view.url_for_license(license)}"
      end
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
