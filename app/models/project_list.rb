class ProjectList < List
  belongs_to :project
  before_validation :set_defaults
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
    project.project_users.exists?(["role IN ('curator', 'manager') AND user_id = ?", user])
  end
    
  private
  def set_defaults
    self.title ||= I18n.t('project_list_defaults.title', owner_name: owner_name)
    self.description ||= I18n.t('project_list_defaults.description', owner_name: owner_name)
    true
  end
end
