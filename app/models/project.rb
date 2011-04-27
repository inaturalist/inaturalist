class Project < ActiveRecord::Base
  belongs_to :user
  has_many :project_users, :dependent => :delete_all
  has_many :project_observations, :dependent => :destroy
  has_many :users, :through => :project_users
  has_many :observations, :through => :project_observations
  has_one :project_list, :dependent => :destroy
  has_many :listed_taxa, :through => :project_list
  has_many :taxa, :through => :listed_taxa
  has_many :project_assets, :dependent => :destroy
  has_one :custom_project, :dependent => :destroy
  
  after_create :add_owner_as_project_user, :create_the_project_list
  
  has_rules_for :project_users, :rule_class => ProjectUserRule
  has_rules_for :project_observations, :rule_class => ProjectObservationRule
  
  has_friendly_id :title, :use_slug => true, :reserved_words => ProjectsController.action_methods.to_a
  
  # For some reason these don't work here
  # accepts_nested_attributes_for :project_user_rules, :allow_destroy => true
  # accepts_nested_attributes_for :project_observation_rules, :allow_destroy => true
  
  validates_length_of :title, :within => 1..85
  validates_presence_of :user_id
  
  has_attached_file :icon, 
    :styles => { :thumb => "48x48#", :mini => "16x16#", :span1 => "30x30#", :span2 => "70x70#" },
    :path => ":rails_root/public/attachments/:class/:attachment/:id/:style/:basename.:extension",
    :url => "/attachments/:class/:attachment/:id/:style/:basename.:extension",
    :default_url => "/attachment_defaults/general/:style.png"
  
  CONTEST_TYPE = 'contest'
  PROJECT_TYPES = [CONTEST_TYPE]
  RESERVED_TITLES = ProjectsController.action_methods
  validates_exclusion_of :title, :in => RESERVED_TITLES + %w(user)
  
  
  def add_owner_as_project_user
    first_user = self.project_users.create(:user => user, :role => "curator")
    true
  end
  
  def create_the_project_list
    create_project_list
    true
  end
  
  def contest?
    project_type == CONTEST_TYPE
  end
  
  def editable_by?(user)
    user.id == user_id || user.is_admin?
  end
  
  def self.refresh_project_list(project, options = {})
    unless project.is_a?(Project)
      project = Project.find_by_id(project, :include => :project_list)
    end
    
    if project.blank?
      Rails.logger.error "[ERROR #{Time.now}] Failed to refresh list for " + 
        "project #{project} because it doesn't exist."
      return
    end
    
    project.project_list.refresh(options)
  end
end
