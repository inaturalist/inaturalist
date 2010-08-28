class ProjectUser < ActiveRecord::Base
  belongs_to :project
  belongs_to :user
  validates_rules_from :project, :rule_methods => [:has_time_zone?, :id_is_even?]
  
  def has_time_zone?
    user.time_zone?
  end
  
  def id_is_even?
    user_id % 2 == 0
  end
  
end
