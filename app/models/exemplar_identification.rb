# frozen_string_literal: true

class ExemplarIdentification < ApplicationRecord
  acts_as_elastic_model

  belongs_to :identification
  belongs_to :nominated_by_user, class_name: "User"

  acts_as_votable
  # acts_as_votable automatically includes `has_subscribers` but
  # we don't want people to subscribe to ExemplarIdentifications. Without this,
  # voting on ExemplarIdentification would invoke auto-subscription to the votable
  SUBSCRIBABLE = false

  validates_presence_of :identification
  validates_presence_of :nominated_by_user, if: :nominated_by_user_id?
  validate :identification_body_has_text
  validate :nominated_by_user_has_permission

  before_save :set_nominated_at
  before_save :set_active

  attr_accessor :identification_body_recently_emptied

  def identification_body_has_text
    return if identification_body_recently_emptied
    return unless identification&.body&.strip.blank?

    errors.add( :identification, "requires a body" )
  end

  def nominated_by_user_has_permission
    return unless nominated_by_user&.content_creation_restrictions?

    errors.add( :nominated_by_user, :requires_privilege_organizer )
  end

  def set_nominated_at
    return unless will_save_change_to_nominated_by_user_id?

    self.nominated_at = nominated_by_user_id.blank? ? nil : Time.now
  end

  def set_active
    unless identification.current? &&
        identification.taxon.species_or_lower? &&
        ( !identification.observation.taxon ||
          identification.observation.taxon.self_and_ancestor_ids.include?( identification.taxon_id )
        )
      self.active = false
      return
    end

    self.active = true
  end

  def votable_callback
    self.wait_for_index_refresh = true
    elastic_index!
  end
end
