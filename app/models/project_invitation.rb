class ProjectInvitation < ActiveRecord::Base
  belongs_to :project
  belongs_to :observation
  belongs_to :user
  validates_presence_of :project_id, :observation_id, :user_id
  validate :invited_by_project_member?, :on => :create
  after_destroy :expire_caches
  validate :must_not_be_a_project_observation
  validates_uniqueness_of :observation_id, :scope => :project_id, :message => "already invited to this project"
  notifies_owner_of :observation, :notification => "activity"
  
  def invited_by_project_member?
    self.project.project_users.exists?(:user_id => self.user_id) && self.observation.user_id != self.user_id
  end

  def expire_caches
    ctrl = ActionController::Base.new
    ctrl.expire_fragment(FakeView.home_url(:user_id => observation.user_id).gsub('http://', ''))
    true
  end
end

##### Validations #########################################################
#
# Make sure the a project_invitation can't be created for a project and observation that already has a project_observation.
#
def must_not_be_a_project_observation
  if ProjectObservation.where(observation_id: self.observation_id, project_id: self.project_id).any?
    errors.add(:observation_id, "can't be used to make invitation when project_observation exists for same observation_id and project_id")
  end
  true
end
