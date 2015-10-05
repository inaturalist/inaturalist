module DarwinCore
  class SimpleMultimedia

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
      %w(rightsHolder http://purl.org/dc/terms/rightsHolder)
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
        "StillImage"
      end

      def format
        file_content_type
      end

      def identifier
        original_url
      end

      def references
        native_page_url
      end

      def created
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
        if is_a?(LocalPhoto)
          "iNaturalist"
        else
          self.class.name.sub(/Photo$/, '').underscore.titleize
        end
      end

      def dwc_license
        license_url
      end

      def rightsHolder
        attribution_name
      end

    end
  end
end
