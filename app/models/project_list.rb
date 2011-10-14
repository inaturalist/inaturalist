class ProjectList < LifeList
  belongs_to :project
  validates_presence_of :project_id
  
  def owner
    project
  end
  
  def owner_name
    project.title
  end
  
  def listed_taxa_editable_by?(user)
    return false if user.blank?
    project.project_users.exists?(:user_id => user)
  end
  
  # Curators and admins can alter the list.
  def editable_by?(user)
    return false if user.blank?
    project.project_users.exists?(:role => "curator", :user_id => user)
  end
  
  def first_observation_of(taxon)
    return nil unless taxon
    project.observations.recently_added.of(taxon).last
  end
  
  def last_observation_of(taxon)
    return nil unless taxon
    project.observations.of(taxon).latest.first
  end
  
  def observation_stats_for(taxon, options = {})
    project.observations.of(taxon).count(:group => "EXTRACT(month FROM observed_on)")
  end
  
  
  private
  def set_defaults
    self.title ||= "%s's Check List" % owner_name
    self.description ||= "The species list for #{owner_name}"
    true
  end
end
