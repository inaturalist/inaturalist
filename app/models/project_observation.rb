class ProjectObservation < ActiveRecord::Base
  belongs_to :project
  belongs_to :observation
  validates_presence_of :project_id, :observation_id
  validate_on_create :observed_by_project_member?
  validates_rules_from :project, :rule_methods => [:observed_in_place?]
  validates_uniqueness_of :observation_id, :scope => :project_id, :message => "already added to this project"
  
  def observed_by_project_member?
    project.project_users.exists?(:user_id => observation.user_id)
  end
  
  def observed_in_place?(place)
    place.contains_lat_lng?(observation.latitude, observation.longitude)
  end
  
  def observed_in_bounding_box_of?(place)
    place.bbox_contains_lat_lng?(observation.latitude, observation.longitude)
  end
  
end
