class ProjectObservation < ActiveRecord::Base
  belongs_to :project
  belongs_to :observation
  validates_presence_of :project_id, :observation_id
  validate_on_create :observed_by_project_member?
  validates_rules_from :project, :rule_methods => [:observed_in_place?, :georeferenced?, :identified?]
  validates_uniqueness_of :observation_id, :scope => :project_id, :message => "already added to this project"
  
  after_save :refresh_project_list
  after_destroy :refresh_project_list
  after_create :update_observation_counter_cache
  after_destroy :update_observation_counter_cache
  after_create :update_taxon_counter_cache
  after_destroy :update_taxon_counter_cache
  
  def observed_by_project_member?
    project.project_users.exists?(:user_id => observation.user_id)
  end
  
  def refresh_project_list
    return true if observation.taxon_id.blank?
    Project.send_later(:refresh_project_list, project_id, 
      :taxa => [observation.taxon_id], :add_new_taxa => id_was.nil?)
    true
  end
  
  def update_observation_counter_cache
    project_user = project.project_users.find_by_user_id(observation.user_id)
    return true unless project_user
    thecount = project.project_observations.count(
      :include => {:observation => :taxon},
      :conditions => [
        "observations.user_id = ? AND taxa.rank_level <= ?", 
        project_user.user_id, Taxon::RANK_LEVELS['species']
      ]
    )
    project_user.send_later(:update_attribute, :observations_count, thecount)
    true
  end
  
  def update_taxon_counter_cache
    project_user = project.project_users.find_by_user_id(observation.user_id)
    return true unless project_user
    thecount = project_user.project.project_observations.count(
      :select => "distinct observations.taxon_id",
      :include => {:observation => :taxon},
      :conditions => [
        "observations.user_id = ? AND taxa.rank_level <= ?", 
        project_user.user_id, Taxon::RANK_LEVELS['species']
      ]
    )
    project_user.send_later(:update_attribute, :taxa_count, thecount)
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
