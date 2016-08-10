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

  end
end
