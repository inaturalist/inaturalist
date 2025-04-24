# frozen_string_literal: true

class ModeratorAction < ApplicationRecord
  HIDE = "hide"
  RENAME = "rename"
  UNHIDE = "unhide"
  SUSPEND = "suspend"
  UNSUSPEND = "unsuspend"
  ACTIONS = [
    HIDE,
    RENAME,
    SUSPEND,
    UNHIDE,
    UNSUSPEND
  ].freeze
  MINIMUM_REASON_LENGTH = 10
  MAXIMUM_REASON_LENGTH = 2048

  PRIVATE_MEDIA_RETENTION_TIME = 2.months

  belongs_to :user, inverse_of: :moderator_actions
  belongs_to :resource, polymorphic: true, inverse_of: :moderator_actions
  belongs_to :resource_parent, polymorphic: true
  belongs_to :resource_user,
    class_name: "User",
    foreign_key: "resource_user_id",
    inverse_of: :moderator_actions_as_resource_user
  validates :action, inclusion: ACTIONS
  validates :reason, length: { minimum: MINIMUM_REASON_LENGTH, maximum: MAXIMUM_REASON_LENGTH }
  validate :only_curators_and_staff_can_hide, on: :create
  validate :only_staff_can_make_private
  validate :only_staff_can_rename, on: :create
  validate :only_hidden_content_can_be_private
  validate :only_staff_and_hiding_curator_can_unhide, on: :create
  validate :check_accepted_actions, on: :create
  validate :cannot_suspend_staff

  before_create :set_resource_user_id
  before_create :set_resource_content
  before_create :set_resource_parent

  after_save :touch_resource
  after_save :notify_resource
  after_save :delete_resource_update_actions, if: ->( moderator_action ) { moderator_action.action == HIDE }
  after_destroy :notify_resource_on_destroy

  def self.current_private_actions
    moderated_private_resource_ids = ModeratorAction.where( private: true ).pluck( :resource_id )
    ids_of_active_moderated_private_resources = ModeratorAction.
      select( "resource_id, MAX(id) as id" ).
      where( resource_id: moderated_private_resource_ids ).
      group( :resource_id ).select( &:id )
    ModeratorAction.where( id: ids_of_active_moderated_private_resources, private: true )
  end

  # Whether or not a resource can be unhidden by a given user
  def self.unhideable_by?( resource, user )
    return false unless user
    return false unless resource
    return true if user.is_admin?

    most_recent_moderator_action_on_item = resource.most_recent_moderator_action
    # curators that were the most recent to hide the content can also unhide it
    most_recent_moderator_action_on_item &&
      most_recent_moderator_action_on_item.action == HIDE &&
      most_recent_moderator_action_on_item.user_id == user.id
  end

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
    return if ModeratorAction.unhideable_by?( resource, user )

    errors.add( :base, :only_staff_and_hiding_curators_can_unhide )
  end

  def only_staff_can_rename
    return unless action == RENAME
    return if user&.is_admin?

    errors.add( :base, :only_staff_can_rename )
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

  def delete_resource_update_actions
    UpdateAction.where( resource: resource ).destroy_all
    UpdateAction.where( notifier: resource ).destroy_all
  end

  def set_resource_user_id
    return unless resource

    user = Flag.instance_user( resource )
    return if user.blank?

    self.resource_user_id = user.id
  end

  def set_resource_content
    return unless resource
    return if action == RENAME

    self.resource_content = Flag.instance_content( resource )
  end

  def set_resource_parent
    return unless resource

    self.resource_parent = Flag.instance_parent( resource )
  end
end
