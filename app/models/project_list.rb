class ProjectList < LifeList
  belongs_to :project
  validates_presence_of :project_id
  
  def owner
    project
  end
  
  def owner_name
    project.title
  end
  
  def refresh(options = {})
    # ProjectLists listed taxa *must* be observed
    super(options.merge(:destroy_unobserved => true))
  end
  
  def last_observation_of(taxon)
    return nil unless taxon
    Observation.latest.first(
      :include => :project_observations, 
      :conditions => [
        "taxon_id = ? AND project_observations.project_id = ?", taxon, project_id
      ])
  end
  
  private
  def set_defaults
    self.title ||= "%s's Check List" % owner_name
    self.description ||= "Every species observed by members of #{owner_name}"
    true
  end
end
