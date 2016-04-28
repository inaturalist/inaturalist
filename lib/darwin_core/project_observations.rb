module DarwinCore
  class ProjectObservations

    TERMS = [
      ['id', 'id', nil, 'observation_id'],
      ['identifier', 'http://purl.org/dc/terms/identifier', nil, 'id'],
      %w(projectID projectID),
      %w(projectTitle projectTitle),
      %w(created http://purl.org/dc/terms/created),
      %w(modified http://purl.org/dc/terms/modified),
    ]
    TERM_NAMES = TERMS.map{|name, uri| name}

    def self.adapt(record, options = {})
      record.extend(InstanceMethods)
      record.extend(DarwinCore::Helpers)
      record.observation = options[:observation]
      record.core = options[:core]
      record
    end
    
    module InstanceMethods
      attr_accessor :observation
      attr_accessor :core

      def view
        @view ||= FakeView
      end

      def set_view(view)
        @view = view
      end

      def projectTitle
        project.title
      end

      def projectID
        view.project_url( project_id )
      end

      def created
        created_at.iso8601
      end

      def modified
        updated_at.iso8601
      end

      def value
        dwc_filter_text( super )
      end

    end
  end
end
