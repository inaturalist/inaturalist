class ProjectList < LifeList
  belongs_to :project
  validates_presence_of :project_id
  
  def owner
    project
  end
  
  def owner_name
    project.title
  end
  
  private
  def set_defaults
    self.title ||= "%s's Check List" % owner_name
    self.description ||= "Every species observed by members of #{owner_name}"
    true
  end
end
