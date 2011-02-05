class ProjectObservation < ActiveRecord::Base
  belongs_to :project
  belongs_to :observation
  validates_presence_of :project_id, :observation_id
  validate_on_create :observed_by_project_member?
  validates_rules_from :project, :rule_methods => [:observed_in_place?, :georeferenced?, :identified?]
  validates_uniqueness_of :observation_id, :scope => :project_id, :message => "already added to this project"
  
  after_save :refresh_project_list
  after_destroy :refresh_project_list
  
  def observed_by_project_member?
    project.project_users.exists?(:user_id => observation.user_id)
  end
  
  def refresh_project_list
    return true if observation.taxon_id.blank?
    Project.send_later(:refresh_project_list, project_id, 
      :taxa => [observation.taxon_id], :add_new_taxa => id_was.nil?)
    true
  end
  
  ##### Rules ###############################################################
  def observed_in_place?(place)
    place.contains_lat_lng?(observation.latitude, observation.longitude)
  end
  
  def observed_in_bounding_box_of?(place)
    place.bbox_contains_lat_lng?(observation.latitude, observation.longitude)
  end
  
  def georeferenced?
    !observation.latitude.blank? && !observation.longitude.blank?
  end
  
  def identified?
    !observation.taxon_id.blank?
  end
  
end
