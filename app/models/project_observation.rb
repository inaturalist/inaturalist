class ProjectObservation < ActiveRecord::Base
  belongs_to :project
  belongs_to :observation
  validates_presence_of :project_id, :observation_id
  validates_rules_from :project
  
  def observed_by_a_member_of?(project)
    project.project_users.exists?(:user_id => observation.user_id)
  end
  
end
