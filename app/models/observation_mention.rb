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

  def self.create_for( record )
    text = record.try_methods( :body, :description )
    return if text.blank?

    ids = extract_observation_ids( text )
    return if ids.blank?

    ids.each do | observation_id |
      m = ObservationMention.new( observation_id: observation_id, sender: record )
      m.created_at = record.created_at
      unless m.save
        Rails.logger.error "failed to save ObservationMention in #{self}: #{m.errors.full_messages.to_sentence}"
      end
    end
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
