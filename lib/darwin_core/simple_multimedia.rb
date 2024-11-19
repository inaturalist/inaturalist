module DarwinCore
  class SimpleMultimedia
    include Helpers

    # http://rs.gbif.org/terms/1.0/Multimedia
    TERMS = [
      ['id', 'id', nil, 'core_id'],
      ['type', 'http://purl.org/dc/terms/type', nil, 'dwc_type'],
      %w(format http://purl.org/dc/terms/format),
      %w(identifier http://purl.org/dc/terms/identifier),
      %w(references http://purl.org/dc/terms/references),
      %w(created http://purl.org/dc/terms/created),
      %w(creator http://purl.org/dc/terms/creator),
      %w(publisher http://purl.org/dc/terms/publisher),
      ['license', 'http://purl.org/dc/terms/license', nil, 'dwc_license'],
      %w(rightsHolder http://purl.org/dc/terms/rightsHolder),
      # Not technically a part of the Simple Multimedia extension, but serves
      # as a place to store the photo ID
      %w(catalogNumber http://rs.tdwg.org/dwc/terms/catalogNumber)
    ]
    TERM_NAMES = TERMS.map{|name, uri| name}

    def self.adapt(record, options = {})
      record.extend(InstanceMethods)
      record.observation = options[:observation]
      record.core = options[:core]
      record
    end
    
    module InstanceMethods
      attr_accessor :observation
      attr_accessor :core

      def core_id
        if core == 'taxon'
          observation.taxon_id
        else
          observation.id
        end
      end

      def dwc_type
        if is_a?( Photo )
          "StillImage"
        else
          "Sound"
        end
      end

      def format
        file_content_type
      end

      # Note that this is *supposed* to be a URL to locate the resource, *not* a
      # unique identifier for the image
      def identifier
        if is_a?( Photo )
          best_url( "original" )
        elsif is_a?( LocalSound )
          FakeView.uri_join( Site.default.url, file.url )
        end
      end

      def references
        return native_page_url unless native_page_url.blank?
        return FakeView.sound_url( self ) if is_a?( Sound )

        FakeView.photo_url( self )
      end

      def created
        if is_a?( Sound )
          return created_at.iso8601
        end
        if metadata && metadata[:date_time_original]
          t = Time.parse(metadata[:date_time_original]).iso8601 rescue nil
          t ||= metadata[:date_time_original].iso8601 rescue nil
        end
        t ||= observation.time_observed_at.iso8601 if observation.time_observed_at
        t ||= observation.observed_on.to_s if observation.observed_on
        t
      end

      def creator
        attribution_name
      end

      def publisher
        if is_a?( LocalPhoto ) || is_a?( LocalSound )
          "iNaturalist"
        else
          self.class.name.sub(/(Photo|Sound)$/, '').underscore.titleize
        end
      end

      def dwc_license
        license_url
      end

      def rightsHolder
        attribution_name
      end

      def catalogNumber
        id
      end

    end
  end
end
