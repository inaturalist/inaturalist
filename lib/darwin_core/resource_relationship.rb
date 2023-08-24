module DarwinCore
  class ResourceRelationship

    TERMS = [
      ['id', 'id', nil, 'observation_id'],
      %w(identifier http://purl.org/dc/terms/identifier),
      %w(resourceID http://rs.tdwg.org/dwc/terms/resourceID),
      %w(relationshipOfResourceID http://rs.tdwg.org/dwc/terms/relationshipOfResourceID),
      %w(relationshipOfResource http://rs.tdwg.org/dwc/terms/relationshipOfResource),
      %w(relatedResourceID http://rs.tdwg.org/dwc/terms/relatedResourceID),
      %w(relationshipAccordingTo http://rs.tdwg.org/dwc/terms/relationshipAccordingTo),
      %w(relationshipEstablishedDate http://rs.tdwg.org/dwc/terms/relationshipEstablishedDate)
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

      def identifier
        id
      end

      def resourceID
        FakeView.observation_url( observation_id )
      end

      def relationshipOfResourceID
        FakeView.observation_field_url( observation_field_id )
      end

      def relationshipOfResource
        observation_field.name
      end

      def relatedResourceID
        FakeView.taxon_url( value )
      end

      def relationshipAccordingTo
        FakeView.person_url( user.login )
      end

      def relationshipEstablishedDate
        created_at.iso8601
      end
    end
  end
end
