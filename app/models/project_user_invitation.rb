#encoding: utf-8
class ProjectUserInvitation < ApplicationRecord
  belongs_to :user, :inverse_of => :project_user_invitations
  belongs_to :invited_user, :class_name => "User", :inverse_of => :project_user_invitations_received
  belongs_to :project, :inverse_of => :project_user_invitations
  validates_presence_of :user_id, :invited_user_id, :project_id
  validates_uniqueness_of :invited_user_id, :scope => :project_id, :message => "has already been invited"
  validate :user_is_not_already_a_member
  validate :user_has_not_blocked_owner
  validate :owner_has_not_blocked_user
  after_create :email_user, :create_update_for_user
  after_destroy :destroy_updates

  def email_user
    Emailer.project_user_invitation(self).deliver_now
  end

  def create_update_for_user
    action_attrs = {
      resource: self,
      notifier: self,
      notification: "invited"
    }
    if action = UpdateAction.first_with_attributes(action_attrs)
      action.append_subscribers( [invited_user.id] )
    end
  end

  def destroy_updates
    UpdateAction.delete_and_purge(
      resource_type: "ProjectUserInvitation",
      resource_id: id)
  end

  def accepted?
    @accepted = ProjectUser.where(:project_id => project_id, :user_id => invited_user_id).exists?
  end

  def pending?
    !accepted?
  end

  def user_is_not_already_a_member
    return if project_id.blank? || invited_user_id.blank?

    if ProjectUser.where(:project_id => project_id, :user_id => invited_user_id).exists?
      errors.add(:invited_user_id, "is already a member of that project")
    end
  end

  def owner_has_not_blocked_user
    return if project_id.blank? || invited_user_id.blank?

    if UserBlock.where(user_id: project.user_id, blocked_user_id: invited_user_id).any?
      errors.add(:invited_user_id, "is blocked by the owner of the project")
    end
  end

  def user_has_not_blocked_owner
    return if project_id.blank? || invited_user_id.blank?

    if UserBlock.where(user_id: invited_user_id, blocked_user_id: project.user_id).any?
      errors.add(:invited_user_id, "has blocked the owner of the project")
    end
  end
end
