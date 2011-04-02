class ProjectUser < ActiveRecord::Base
  
  belongs_to :project
  belongs_to :user
  before_destroy :prevent_owner_from_leaving
  validates_uniqueness_of :user_id, :scope => :project_id, :message => "already a member of this project"
  validates_rules_from :project, :rule_methods => [:has_time_zone?]
  
  def prevent_owner_from_leaving
    raise "The owner of a project can't leave the project" if project.user_id == user_id
  end
  
  def has_time_zone?
    user.time_zone?
  end
  
  def is_curator?
    role == 'curator'
  end
  
end
