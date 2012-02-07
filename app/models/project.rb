class Project < ActiveRecord::Base
  belongs_to :user
  has_many :project_users, :dependent => :delete_all
  has_many :project_observations, :dependent => :destroy
  has_many :project_invitations, :dependent => :destroy
  has_many :users, :through => :project_users
  has_many :observations, :through => :project_observations
  has_one :project_list, :dependent => :destroy
  has_many :listed_taxa, :through => :project_list
  has_many :taxa, :through => :listed_taxa
  has_many :project_assets, :dependent => :destroy
  has_one :custom_project, :dependent => :destroy
  
  before_save :strip_title
  after_create :add_owner_as_project_user, :create_the_project_list
  
  has_rules_for :project_users, :rule_class => ProjectUserRule
  has_rules_for :project_observations, :rule_class => ProjectObservationRule
  
  has_friendly_id :title, :use_slug => true, 
    :reserved_words => ProjectsController.action_methods.to_a
  
  preference :count_from_list, :boolean, :default => false
  preference :place_boundary_visible, :boolean, :default => false
  
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
  
  def strip_title
    self.title = title.strip
    true
  end
  
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
  
  def curated_by?(user)
    return false if user.blank?
    return true if user.is_admin?
    project_users.curators.exists?(:user_id => user.id)
  end
  
  def rule_place
    project_observation_rules.first(:conditions => {:operator => "observed_in_place?"}).try(:operand)
  end
  
  def self.update_curator_idents_on_make_curator(project_id, project_user_id)
    unless proj = Project.find_by_id(project_id)
      return
    end
    unless usr = proj.project_users.find_by_id(project_user_id).user
      return
    end
    proj.project_observations.find_each(:include => {:observation => :identifications}) do |po|
      po.observation.identifications.each do |ident|
        if ident.user.project_users.exists?(:id => project_user_id, :project_id => project_id)
          po.update_attributes(:curator_identification_id => ident.id)
          ProjectUser.send_later(:update_observations_counter_cache_from_project_and_user, project_id, po.observation.user_id)
          ProjectUser.send_later(:update_taxa_counter_cache_from_project_and_user, project_id, po.observation.user_id)
        end
      end
    end
  end
  
  def self.update_curator_idents_on_remove_curator(project_id, user_id)
    unless proj = Project.find_by_id(project_id)
      return
    end
    unless usr = User.find_by_id(user_id) #on delete user
      proj.project_observations.find_each(:include => {:observation => :identifications}) do |po|
        po.observation.identifications.each do |ident| #loop through all idents in all pos in the proj - big job
          other_curator_id = false
          po.observation.identifications.each do |other_ident| #that project observation has other identifications that belong to users who are curators use those
            if other_ident.user.project_users.exists?(:project_id => po.project_id, :role => 'curator')
              po.update_attributes(:curator_identification_id => other_ident.id)
              other_curator_id = true
            end
          end
          unless other_curator_id
            po.update_attributes(:curator_identification_id => nil)
          end
          ProjectUser.send_later(:update_observations_counter_cache_from_project_and_user, project_id, po.observation.user_id)
          ProjectUser.send_later(:update_taxa_counter_cache_from_project_and_user, project_id, po.observation.user_id)
        end
      end
      return
    end
    proj.project_observations.find_each(:include => {:observation => :identifications}) do |po|
      po.observation.identifications.each do |ident|
        if ident.user.id == user_id #ident belongs to the user of interest
          other_curator_id = false
          po.observation.identifications.each do |other_ident| #that project observation has other identifications that belong to users who are curators use those
            if other_ident.user.project_users.exists?(:project_id => po.project_id, :role => 'curator')
              po.update_attributes(:curator_identification_id => other_ident.id)
              other_curator_id = true
            end
          end
          unless other_curator_id
            po.update_attributes(:curator_identification_id => nil)
          end
          ProjectUser.send_later(:update_observations_counter_cache_from_project_and_user, project_id, po.observation.user_id)
          ProjectUser.send_later(:update_taxa_counter_cache_from_project_and_user, project_id, po.observation.user_id)
        end
      end
    end
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
  
  def self.update_observed_taxa_count(project_id)
    #This way does uses curator IDs which is awesome, but is different from
    #total_observed_taxa (which is project.project_list.listed_taxa.count(:conditions => "last_observation_id IS NOT NULL") )
    #making this too confusing until total_observed_taxa can be made to also use curator IDs for project lists
    #user_taxon_ids = ProjectObservation.all(
    #  :select => "distinct observations.taxon_id",
    #  :include => [{:observation => :taxon}, :curator_identification],
    #  :conditions => [
    #    "identifications.id IS NULL AND project_id = ?",
    #    project_id
    #  ]
    #).map{|po| po.observation.taxon_id}
    #
    #curator_taxon_ids = ProjectObservation.all(
    #  :select => "distinct identifications.taxon_id",
    #  :include => [:observation, {:curator_identification => :taxon}],
    #  :conditions => [
    #    "identifications.id IS NOT NULL AND project_id = ?",
    #    project_id
    #  ]
    #).map{|po| po.curator_identification.taxon_id}
    
    project = Project.find_by_id(project_id)
    #project.update_attributes(:observed_taxa_count => (user_taxon_ids + curator_taxon_ids).uniq.size)
    observed_taxa_count = project.project_list.listed_taxa.count(:conditions => "last_observation_id IS NOT NULL")
    project.update_attributes(:observed_taxa_count => observed_taxa_count)
  end
  
  
  def self.delete_project_observations_on_leave_project(project_id, user_id)
    unless proj = Project.find_by_id(project_id)
      return
    end
    unless usr = User.find_by_id(user_id)
      return
    end
    proj.project_observations.find_each(:include => :observation, :conditions => ["observations.user_id = ?", usr]) do |po|
      po.destroy
    end
  end
end
