module ActsAsUUIDable

  extend ActiveSupport::Concern

  included do

    validates_uniqueness_of :uuid
    before_validation :set_uuid

    def set_uuid
      self.uuid ||= SecureRandom.uuid
      self.uuid = uuid.downcase
      true
    end

    # If we seem to be assigning a UUID to the id column, ignore it
    def id=(new_id)
      return if new_id.to_s =~ BelongsToWithUuid::UUID_PATTERN
      super( new_id )
    end

  end
end
