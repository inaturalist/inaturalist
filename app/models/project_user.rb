class ProjectUser < ActiveRecord::Base
  belongs_to :project
  belongs_to :user
  validates_rules_from :project, :rule_methods => [:has_time_zone?]
  
  def has_time_zone?
    user.time_zone?
  end
  
end
