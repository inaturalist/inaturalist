class ProjectInvitation < ActiveRecord::Base
  belongs_to :project
  belongs_to :observation
  belongs_to :user
  validates_presence_of :project_id, :observation_id, :user_id
  validate_on_create :invited_by_project_member?
  after_create :deliver_notification
  
  def invited_by_project_member?
    self.project.project_users.exists?(:user_id => self.user_id) && self.observation.user_id != self.user_id
  end
  
  def deliver_notification
    if self.observation.user_id != self.user_id && 
        !self.observation.user.email.blank? && self.observation.user.preferences.project_invitation_email_notification
      Emailer.send_later(:deliver_project_invitation_notification, self)
    end
    true
  end
end
