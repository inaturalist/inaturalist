class Identification < ActiveRecord::Base
  belongs_to :observation
  belongs_to :user
  belongs_to :taxon
  has_many :project_observations, :foreign_key => :curator_identification_id, :dependent => :nullify
  validates_presence_of :observation_id, :user_id
  validates_presence_of :taxon_id, 
                        :message => "for an ID must be something we recognize"
  validates_uniqueness_of :user_id, :scope => :observation_id, 
                          :message => "can only identify an observation once"
  
  after_create  :update_observation, 
                :increment_user_counter_cache, 
                # :notify_observer, 
                :expire_caches
                
  after_save    :update_obs_stats, 
                :update_curator_identification
                
  after_destroy :revisit_curator_identification, 
                :decrement_user_counter_cache, 
                :update_observation_after_destroy,
                :update_obs_stats,
                :expire_caches
  
  attr_accessor :skip_observation
  
  notifies_subscribers_of :observation, :notification => "activity", :include_owner => true
  auto_subscribes :user, :to => :observation
  
  named_scope :for, lambda {|user|
    {:include => :observation,
    :conditions => ["observation.user_id = ?", user]}
  }
  
  named_scope :for_others,
    :include => :observation,
    :conditions => "observations.user_id != identifications.user_id"
  
  named_scope :by, lambda {|user|
    {:conditions => ["identifications.user_id = ?", user]}
  }
  
  def to_s
    "<Identification #{id} observation_id: #{observation_id} taxon_id: #{taxon_id} user_id: #{user_id}"
  end
  
  # Callbacks ###############################################################
  
  # Update the observation if you're adding an ID to your own obs
  def update_observation
    return false unless observation
    return true unless self.user_id == self.observation.user_id
    return true if @skip_observation

    # update the species_guess
    species_guess = observation.species_guess
    unless taxon.taxon_names.exists?(:name => species_guess)
      species_guess = taxon.to_plain_s
    end
    observation.skip_identifications = true
    observation.update_attributes(:species_guess => species_guess, :taxon => taxon, :iconic_taxon_id => taxon.iconic_taxon_id)
    ProjectUser.send_later(:update_taxa_obs_and_observed_taxa_count_after_update_observation, observation.id, self.user_id)
    true
  end
  
  def update_observation_after_destroy
    return true unless self.observation
    return true unless self.observation.user_id == self.user_id
    return true if @skip_observation
    
    # update the species_guess
    species_guess = observation.species_guess
    if !taxon.blank? && !taxon.taxon_names.exists?(:name => species_guess)
      species_guess = nil
    end
    
    observation.skip_identifications = true
    observation.update_attributes(:species_guess => species_guess, :taxon => nil, :iconic_taxon_id => nil)
    ProjectUser.send_later(:update_taxa_obs_and_observed_taxa_count_after_update_observation, observation.id, self.user_id)
    true
  end
  
  #
  # Update the identification stats in the observation.
  #
  def update_obs_stats
    return true unless observation
    return true if @skip_observation
    observation.update_stats(:include => self)
    true
  end
  
  # Set the project_observation curator_identification_id if the
  #identifier is a curator of a project that the observation is submitted to
  def update_curator_identification
    return true if self.observation.id.blank?
    Identification.send_later(:run_update_curator_identification, self)
    true
  end
  
  # Update the counter cache in users.  That cache ONLY tracks observations 
  # made for others.
  def increment_user_counter_cache
    return true unless self.user && self.observation
    if self.user_id != self.observation.user_id
      self.user.increment!(:identifications_count)
    end
    true
  end
  
  def decrement_user_counter_cache
    return true unless self.user && self.observation
    if self.user_id != self.observation.user_id
      self.user.decrement!(:identifications_count)
    end
    true
  end
  
  def notify_observer
    if self.observation.user_id != self.user_id && 
        !self.observation.user.email.blank? && self.observation.user.prefers_identification_email_notification?
      Emailer.send_later(:deliver_identification_notification, self)
    end
    true
  end
  
  def expire_caches
    Identification.send_later(:expire_caches, self.id)
    true
  end
  
  # Revise the project_observation curator_identification_id if the
  # a curator's identification is deleted to be nil or that of another curator
  def revisit_curator_identification
    Identification.send_later(:run_revisit_curator_identification, self.observation_id, self.user_id)
    true
  end
  
  # /Callbacks ##############################################################
  
  #
  # Tests whether this identification should be considered an agreement with
  # the observer's identification.  If this identification has the same taxon
  # or a child taxon of the observer's idnetification, then they agree.
  #
  def is_agreement?(options = {})
    return false if frozen?
    o = options[:observation] || observation
    return false if o.taxon_id.blank?
    return false if o.user_id == user_id
    return true if taxon_id == o.taxon_id
    taxon.in_taxon? o.taxon_id
  end
  
  def is_disagreement?(options = {})
    return false if frozen?
    o = options[:observation] || observation
    return false if o.user_id == user_id
    !is_agreement?
  end
  
  #
  # Tests whether this identification should be considered an agreement with
  # another identification.
  #
  def in_agreement_with?(identification)
    return false unless identification
    return false if identification.taxon_id.nil?
    return true if self.taxon_id == identification.taxon_id
    self.taxon.in_taxon? identification.taxon
  end
  
  # Static ##################################################################
  
  def self.expire_caches(ident)
    ident = Identification.find_by_id(ident) unless ident.is_a?(Identification)
    return unless ident
    ctrl = ActionController::Base.new
    ctrl.expire_fragment(ident.observation.component_cache_key(:for_owner => true))
    ctrl.expire_fragment(ident.observation.component_cache_key)
  rescue => e
    puts "[DEBUG] Failed to expire caches for #{ident}: #{e}"
    puts e.backtrace.join("\n")
  end
  
  def self.run_update_curator_identification(ident)
    obs = ident.observation
    ident.observation.project_observations.each do |po|
      if ident.user.project_users.exists?(["project_id = ? AND role IN (?)", po.project_id, [ProjectUser::MANAGER, ProjectUser::CURATOR]])
        po.update_attributes(:curator_identification_id => ident.id)
        ProjectUser.send_later(:update_observations_counter_cache_from_project_and_user, po.project_id, obs.user_id)
        ProjectUser.send_later(:update_taxa_counter_cache_from_project_and_user, po.project_id, obs.user_id)
        Project.send_later(:update_observed_taxa_count, po.project_id)
      end
    end
  end
  
  def self.run_revisit_curator_identification(observation_id, user_id)
    unless obs = Observation.find_by_id(observation_id)
      return
    end
    unless usr = User.find_by_id(user_id)
      return
    end
    obs.project_observations.each do |po|
      if usr.project_users.exists?(["project_id = ? AND role IN (?)", po.project_id, [ProjectUser::MANAGER, ProjectUser::CURATOR]]) #The ident that was deleted is owned by user who is a curator of a project that that obs belongs to
        other_curator_id = false
        po.observation.identifications.each do |other_ident| #that project observation has other identifications that belong to users who are curators use those
          if other_ident.user.project_users.exists?(["project_id = ? AND role IN (?)", po.project_id, [ProjectUser::MANAGER, ProjectUser::CURATOR]])
            po.update_attributes(:curator_identification_id => other_ident.id)
            other_curator_id = true
          end
        end
        unless other_curator_id
          po.update_attributes(:curator_identification_id => nil)
        end
        ProjectUser.send_later(:update_observations_counter_cache_from_project_and_user, po.project_id, obs.user_id)
        ProjectUser.send_later(:update_taxa_counter_cache_from_project_and_user, po.project_id, obs.user_id)
        Project.send_later(:update_observed_taxa_count, po.project_id)
      end
    end
  end
  
  # /Static #################################################################
  
end
