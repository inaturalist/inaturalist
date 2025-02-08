# frozen_string_literal: true

class ObservationMention < ApplicationRecord
  belongs_to_with_uuid :sender, polymorphic: true
  belongs_to_with_uuid :observation
  belongs_to_with_uuid :user

  validates_uniqueness_of :observation_id, scope: [:sender_type, :sender_id]
  validate :sender_from_other_resource

  before_save :set_user

  def self.extract_observation_ids( text )
    return [] if text.blank?

    text.scan( %r{/observations/(\d+)} ).map( &:last )
  end

  def sender_from_other_resource
    other_resource = sender.try( :observation ) || sender.try( :parent )
    return unless other_resource
    return unless other_resource == observation

    errors.add( :sender, "cannot be recipient" )
  end

  def set_user
    self.user = sender.user if sender.respond_to?( :user )
  end
end
