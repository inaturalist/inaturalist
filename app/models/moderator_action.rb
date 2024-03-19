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

  belongs_to :user, inverse_of: :moderator_actions
  belongs_to :resource, polymorphic: true, inverse_of: :moderator_actions
  validates :action, inclusion: ACTIONS
  validates :reason, length: { minimum: MINIMUM_REASON_LENGTH, maximum: MAXIMUM_REASON_LENGTH }
  validate :only_staff_and_hiding_curator_can_unhide, on: :create
  validate :check_accepted_actions, on: :create
  validate :cannot_suspend_staff

  after_save :touch_resource
  after_save :notify_resource
  after_destroy :notify_resource_on_destroy

  def only_staff_and_hiding_curator_can_unhide
    return unless user
    return unless action == UNHIDE
    return if user.is_admin?

    most_recent_moderator_action_on_item = resource.moderator_actions.order( id: :desc ).first
    # curators that were the most recent to hide the content can also unhide it
    return if most_recent_moderator_action_on_item &&
      most_recent_moderator_action_on_item.action == HIDE &&
      most_recent_moderator_action_on_item.user_id == user.id

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
      user: user.as_indexed_json( no_details: true ),
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
