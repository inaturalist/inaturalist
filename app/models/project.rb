class Project < ActiveRecord::Base
  belongs_to :user
  has_many :project_users, :dependent => :destroy
  has_many :project_observations, :dependent => :destroy
  has_many :users, :through => :project_users
  has_many :observations, :through => :project_observations
  
  has_rules_for :project_users, :rule_class => ProjectUserRule
  has_rules_for :project_observations, :rule_class => ProjectObservationRule
  
  # For some reason these don't work here
  # accepts_nested_attributes_for :project_user_rules, :allow_destroy => true
  # accepts_nested_attributes_for :project_observation_rules, :allow_destroy => true
  
  validates_length_of :title, :within => 1..300
  validates_presence_of :user_id
  
  has_attached_file :icon, 
    :styles => { :medium => "300x300>", :thumb => "48x48#", :mini => "16x16#" },
    :path => ":rails_root/public/attachments/:class/:attachment/:id/:style/:basename.:extension",
    :url => "/attachments/:class/:attachment/:id/:style/:basename.:extension",
    :default_url => "/attachment_defaults/:class/:attachment/defaults/:style.png"
  
  def after_create
    Rails.logger.debug "[DEBUG] creating first project user"
    first_user = self.project_users.create(:user => user)
    Rails.logger.debug "[DEBUG] first_user: #{first_user}"
    true
  end
  
end
