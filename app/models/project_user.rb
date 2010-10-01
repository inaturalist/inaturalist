class ProjectUser < ActiveRecord::Base
  belongs_to :project
  belongs_to :user
  validates_uniqueness_of :user_id, :scope => :project_id, :message => "already a member of this project"
  validates_rules_from :project, :rule_methods => [:has_time_zone?]
  
  def has_time_zone?
    user.time_zone?
  end
  
end
