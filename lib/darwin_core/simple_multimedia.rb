module DarwinCore
  class SimpleMultimedia

    TERMS = [
      %w(occurrenceID http://rs.tdwg.org/dwc/terms/occurrenceID),
      %w(taxonID http://rs.tdwg.org/dwc/terms/taxonID),
      ['type', 'http://purl.org/dc/terms/type', nil, 'dwc_type'],
      %w(format http://purl.org/dc/terms/format),
      %w(identifier http://purl.org/dc/terms/identifier),
      %w(references http://purl.org/dc/terms/references),
      %w(created http://purl.org/dc/terms/created),
      %w(creator http://purl.org/dc/terms/creator),
      %w(publisher http://purl.org/dc/terms/publisher),
      %w(license http://purl.org/dc/terms/license),
      %w(rightsHolder http://purl.org/dc/terms/rightsHolder)
    ]
    TERM_NAMES = TERMS.map{|name, uri| name}

    def self.adapt(record, options = {})
      record.extend(InstanceMethods)
      record.observation = options[:observation]
      record
    end
    
    module InstanceMethods
      attr_accessor :observation

      def occurrenceID
        observation.id
      end

      def taxonID
        observation.taxon_id
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
          metadata[:date_time_original].iso8601
        elsif observation.time_observed_at
          observation.time_observed_at.iso8601
        elsif observation.observed_on
          observation.observed_on.to_s
        end
      end

      def creator
        dwc_user_name
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
        dwc_user_name
      end

      private

      def dwc_user_name
        if attribution_name.to_i != 0
          user.name.blank? ? user.login : user.name
        else
          attribution_name
        end
      end
    end
  end
end
