# frozen_string_literal: true

class UserPrivilege < ApplicationRecord
  belongs_to :user
  belongs_to :revoke_user, class_name: "User"
  validates :user_id, uniqueness: { scope: :privilege }

  SPEECH = "speech"
  ORGANIZER = "organizer"
  COORDINATE_ACCESS = "coordinate_access"
  INTERACTION = "interaction"

  PRIVILEGES = [
    SPEECH,
    ORGANIZER,
    COORDINATE_ACCESS,
    INTERACTION
  ].freeze

  # The earned_#{privilege}? methods are intended to calculate whether the user
  # has *currently* earned a privilege. They might have it without currently
  # earning it if they earned it in the past. The actual entry in the
  # user_privileges table is what determines if they have the privilege,
  # regardless of whether they've earned it.

  def self.earned_speech?( user )
    user.observations.verifiable.limit( 3 ).count == 3 || user.identifications.current.for_others.limit( 3 ).count == 3
  end

  def self.earned_organizer?( user )
    user.confirmed? &&
      user.observations.verifiable.limit( 50 ).count == 50
  end

  def self.earned_coordinate_access?( user )
    return false unless user.created_at < 3.years.ago

    verifiable_obs_count = Observation.elastic_search(
      filters: [
        { term: { "user.id.keyword" => user.id } },
        { terms: { quality_grade: ["research"] } }
      ]
    ).total_entries
    return true if verifiable_obs_count >= 1000

    improving_ids_count = Identification.elastic_search(
      filters: [
        { term: { current: true } },
        { term: { "user.id.keyword" => user.id } },
        { term: { category: "improving" } },
        { term: { own_observation: false } }
      ]
    ).total_entries
    improving_ids_count >= 1000
  end

  def self.earned_interaction?( user )
    # there _should_ be a configured activation date. If there is and it is not active yet,
    # all users gain INTERACTION. After activation, users must have a confirmed email. If
    # for whatever reason the active date is not defined, default to requiring users must
    # have a confirmed email
    if CONFIG.email_confirmation_for_interaction_active_date
      if Time.now >= Date.parse( CONFIG.email_confirmation_for_interaction_active_date )
        return user.confirmed?
      end

      return true
    end
    user.confirmed?
  end

  def self.check( user, privilege )
    user = User.find_by_id( user ) unless user.is_a?( User )
    unless user && respond_to?( "earned_#{privilege}?".to_sym )
      return
    end
    # Uncomment this if you want to automatically revoke privileges
    # if existing = user.user_privileges.where( privilege: privilege ).first
    #   if send( "earned_#{privilege}?", user )
    #     existing.restore!
    #   else
    #     existing.revoke!
    #   end
    # elsif send( "earned_#{privilege}?", user )
    #   UserPrivilege.create!( user: user, privilege: privilege )
    # end
    return if user.user_privileges.where( privilege: privilege ).exists?

    return unless send( "earned_#{privilege}?", user )

    UserPrivilege.create!( user: user, privilege: privilege )
  end

  def restore!( _options = {} )
    update( revoked_at: nil )
  end

  def revoke!( options = {} )
    update!(
      revoked_at: Time.now,
      revoke_user: options[:revoke_user],
      revoke_reason: options[:revoke_reason]
    )
  end

  def revoked?
    !revoked_at.blank?
  end
end
