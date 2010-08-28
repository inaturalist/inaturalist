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
end
