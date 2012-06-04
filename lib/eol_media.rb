# wrappers and constants for expressing iNat records as Darwin Core fields
class EolMedia
  
  TERMS = [
    %w(taxonID http://rs.tdwg.org/dwc/terms/taxonID),
    %w(identifier http://purl.org/dc/terms/identifier),
    %w(type http://purl.org/dc/terms/type http://purl.org/dc/dcmitype/StillImage),
    %w(format http://purl.org/dc/terms/format),
    %w(accessURI http://rs.tdwg.org/ac/terms/accessURI),
    %w(thumbnailURL http://eol.org/schema/media/thumbnailURL),
    %w(furtherInformationURL http://rs.tdwg.org/ac/terms/furtherInformationURL),
    %w(derivedFrom http://rs.tdwg.org/ac/terms/derivedFrom),
    %w(CreateDate http://ns.adobe.com/xap/1.0/CreateDate),
    %w(modified http://purl.org/dc/terms/modified),
    %w(UsageTerms http://ns.adobe.com/xap/1.0/rights/UsageTerms),
    %w(rights http://purl.org/dc/terms/rights),
    %w(Owner http://ns.adobe.com/xap/1.0/rights/Owner),
    %w(publisher http://purl.org/dc/terms/publisher),
    %w(creator http://purl.org/dc/terms/creator),
    %w(spatial http://purl.org/dc/terms/spatial),
    %w(lat http://www.w3.org/2003/01/geo/wgs84_pos#lat),
    %w(long http://www.w3.org/2003/01/geo/wgs84_pos#long),
    %w(referenceID http://eol.org/schema/reference/referenceID),
    %w(description http://purl.org/dc/terms/description)
  ]
  TERM_NAMES = TERMS.map{|name, uri| name}
  
  # Extend observation with DwC methods.  For reasons unclear to me, url
  # methods are protected if you instantiate a view *outside* a model, but not
  # inside.  Otherwise I would just used a more traditional adapter with
  # delegation.
  def self.adapt(record, options = {})
    record.extend(InstanceMethods)
    record.observation = options[:observation]
    record.set_view(options[:view])
    record
  end
  
  module InstanceMethods
    attr_accessor :observation
    
    def view
      @view ||= FakeView
    end

    def set_view(view)
      @view = view
    end
    
    def identifier
      view.photo_url(self)
    end
    
    def taxonID
      taxon_id = observation ? observation.taxon_id : taxon_photos.first.try(:taxon_id)
      view.taxon_url(taxon_id) if taxon_id
    end
    
    def type
      "http://purl.org/dc/dcmitype/StillImage"
    end
    
    def format
      file_content_type.blank? ? "image/jpeg" : file_content_type
    end
    
    def accessURI
      large_url
    end
    
    def thumbnailURL
      thumb_url
    end
    
    def furtherInformationURL
      view.photo_url(self)
    end
    
    def derivedFrom
      native_page_url
    end
    
    def CreateDate
      created_at ? created_at.iso8601 : nil
    end
    
    def modified
      updated_at ? updated_at.iso8601 : nil
    end
    
    def UsageTerms
      license_url
    end
    
    def rights
      s = "Copyright #{send(:Owner)}"
      unless license.to_i == 0
        s += ", licensed under a #{license_name} license: #{license_url}"
      end
      s
    end
    
    def Owner
      if !user.try(:name).blank?
        user.name
      elsif !user.try(:login).blank?
        user.login
      elsif !native_realname.blank?
        native_realname
      else
        native_username
      end
    end
    
    def publisher
      is_a?(LocalPhoto) ? "iNaturalist" : self.class.to_s.gsub(/Photo/, '').underscore.humanize
    end
    
    def creator
      send(:Owner)
    end
    
    def spatial
      observation.try(:place_guess)
    end
    
    def lat
      observation.try(:latitude)
    end
    
    def long
      observation.try(:longitude)
    end
    
    def referenceID
      if observation_photos.first
        view.observation_url(observation_photos.first.observation_id)
      elsif taxon_photos.first
        view.taxon_url(taxon_photos.first.taxon_id)
      end
    end
    
    def description
      view.strip_tags(observation.description) unless (observation.blank? || observation.description.blank?)
    end
    
    protected
    
    def dwc_filter_text(s)
      s.to_s.gsub(/\r\n|\n/, " ")
    end
    
    def observation
      @observation ||= observation_photos.detect{|op|
        !op.observation.taxon_id.blank?
      }.try(:observation)
    end
  end
end
