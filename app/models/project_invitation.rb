class ProjectInvitation < ActiveRecord::Base
  belongs_to :project
  belongs_to :observation
  belongs_to :user
  validates_presence_of :project_id, :observation_id, :user_id
  validate :invited_by_project_member?, :on => :create
  after_create :deliver_notification
  validate :must_not_be_a_project_observation
  validates_uniqueness_of :observation_id, :scope => :project_id, :message => "already invited to this project"
  
  def invited_by_project_member?
    self.project.project_users.exists?(:user_id => self.user_id) && self.observation.user_id != self.user_id
  end
  
  def deliver_notification
    if self.observation.user_id != self.user_id && 
        !self.observation.user.email.blank? && self.observation.user.prefers_project_invitation_email_notification?
      Emailer.delay.deliver_project_invitation_notification(self)
    end
    true
  end
end

##### Validations #########################################################
#
# Make sure the a project_invitation can't be created for a project and observation that already has a project_observation.
#
def must_not_be_a_project_observation

  if ProjectObservation.first(:conditions => {:observation_id => self.observation_id, :project_id => self.project_id})
      errors.add(:observation_id, "can't be used to make invitation when project_observation exists for same observation_id and project_id")
  end
  true
end
