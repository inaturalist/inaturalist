# frozen_string_literal: true

class ModeratorAction < ApplicationRecord
  HIDE = "hide"
  UNHIDE = "unhide"
  SUSPEND = "suspend"
  UNSUSPEND = "unsuspend"
  ACTIONS = [
    HIDE,
    SUSPEND,
    UNHIDE,
    UNSUSPEND
  ].freeze
  MINIMUM_REASON_LENGTH = 10
  MAXIMUM_REASON_LENGTH = 2048

  PRIVATE_MEDIA_RETENTION_TIME = 2.months

  belongs_to :user, inverse_of: :moderator_actions
  belongs_to :resource, polymorphic: true, inverse_of: :moderator_actions
  validates :action, inclusion: ACTIONS
  validates :reason, length: { minimum: MINIMUM_REASON_LENGTH, maximum: MAXIMUM_REASON_LENGTH }
  validate :only_curators_and_staff_can_hide, on: :create
  validate :only_staff_can_make_private
  validate :only_hidden_content_can_be_private
  validate :only_staff_and_hiding_curator_can_unhide, on: :create
  validate :check_accepted_actions, on: :create
  validate :cannot_suspend_staff

  after_save :touch_resource
  after_save :notify_resource
  after_destroy :notify_resource_on_destroy

  def only_curators_and_staff_can_hide
    return unless action == HIDE
    return if user&.is_curator? || user&.is_admin?

    errors.add( :base, :only_staff_and_curators_can_hide )
  end

  def only_staff_can_make_private
    return unless private?
    return if user&.is_admin?

    errors.add( :base, :only_staff_can_make_private )
  end

  def only_hidden_content_can_be_private
    return unless private?
    return if action == HIDE

    errors.add( :base, :only_hidden_content_can_be_private )
  end

  def only_staff_and_hiding_curator_can_unhide
    return unless action == UNHIDE
    return if resource&.unhideable_by?( user )

    errors.add( :base, :only_staff_and_hiding_curators_can_unhide )
  end

  def cannot_suspend_staff
    return unless resource.is_a?( User ) && resource.is_admin? && action == SUSPEND

    errors.add( :base, :staff_cannot_be_suspended )
  end

  def check_accepted_actions
    if resource &&
        resource.class.respond_to?( :accepted_moderator_actions ) &&
        !resource.class.accepted_moderator_actions.blank? &&
        !resource.class.accepted_moderator_actions.include?( action )
      errors.add( :action, :not_supported_for_this_kind_of_content )
    end
  end

  def as_indexed_json
    {
      id: id,
      created_at: created_at,
      created_at_details: ElasticModel.date_details( created_at ),
      user: user&.as_indexed_json( no_details: true ),
      action: action,
      reason: reason
    }
  end

  def touch_resource
    resource.touch
    true
  end

  def notify_resource
    return unless resource.respond_to?( :moderated_with )

    resource.moderated_with( self )
  end

  def notify_resource_on_destroy
    return unless resource.respond_to?( :moderated_with )

    resource.moderated_with( self, action: "destroyed" )
  end
end
