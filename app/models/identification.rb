class Identification < ActiveRecord::Base
  acts_as_flaggable
  belongs_to :observation
  belongs_to :user
  belongs_to :taxon
  belongs_to :taxon_change
  has_many :project_observations, :foreign_key => :curator_identification_id, :dependent => :nullify
  validates_presence_of :observation, :user
  validates_presence_of :taxon, 
                        :message => "for an ID must be something we recognize"
  validate :uniqueness_of_current, :on => :update
  
  after_create  :update_other_identifications,
                :update_observation, 
                :increment_user_counter_cache, 
                :expire_caches
                
  after_save    :update_obs_stats, 
                :update_curator_identification
                
  after_destroy :set_last_identification_as_current,
                :revisit_curator_identification, 
                :decrement_user_counter_cache, 
                :update_observation_after_destroy,
                :update_obs_stats,
                :expire_caches
  
  attr_accessor :skip_observation
  attr_accessor :html
  
  notifies_subscribers_of :observation, :notification => "activity", :include_owner => true, 
    :queue_if => lambda {|ident| ident.taxon_change_id.blank?}
  auto_subscribes :user, :to => :observation, :if => lambda {|ident, observation| 
    ident.user_id != observation.user_id
  }
  
  scope :for, lambda {|user|
    includes(:observation).where("observation.user_id = ?", user)
  }
  scope :for_others, includes(:observation).where("observations.user_id != identifications.user_id")
  scope :by, lambda {|user| where("identifications.user_id = ?", user)}
  scope :of, lambda {|taxon| where("identifications.taxon_id = ?", taxon)}
  scope :on, lambda {|date| where(Identification.conditions_for_date("identifications.created_at", date)) }
  scope :current, where(:current => true)
  scope :outdated, where(:current => false)
  
  def to_s
    "<Identification #{id} observation_id: #{observation_id} taxon_id: #{taxon_id} user_id: #{user_id}"
  end

  def to_plain_s(options = {})
    "Identification #{id} by #{user.login}"
  end

  # Validations ###############################################################

  def uniqueness_of_current
    return true unless observation && user_id
    return true unless current?
    current_ident = observation.identifications.by(user_id).current.last
    if current_ident && current_ident.id != id && current_ident.created_at > created_at
      errors.add(:current, "can't be set when a newer current identification exists for this user")
    end
    true
  end
  
  # Callbacks ###############################################################

  def update_other_identifications
    Identification.update_all(
      ["current = ?", false],
      ["observation_id = ? AND user_id = ? AND id != ?", observation_id, user_id, id]
    )
    true
  end
  
  # Update the observation if you're adding an ID to your own obs
  def update_observation
    return true unless observation
    return true unless self.user_id == self.observation.user_id
    return true if @skip_observation

    # update the species_guess
    species_guess = observation.species_guess
    unless taxon.taxon_names.exists?(:name => species_guess)
      species_guess = taxon.to_plain_s
    end
    observation.skip_identifications = true
    observation.update_attributes(:species_guess => species_guess, :taxon_id => taxon_id, :iconic_taxon_id => taxon.iconic_taxon_id)
    ProjectUser.delay(:priority => INTEGRITY_PRIORITY).update_taxa_obs_and_observed_taxa_count_after_update_observation(observation.id, self.user_id)
    true
  end
  
  def update_observation_after_destroy
    return true unless self.observation
    return true unless self.observation.user_id == self.user_id
    return true if @skip_observation

    if last_current = observation.identifications.current.by(user_id).order("id ASC").last
      last_current.update_observation
      return true
    end
    
    # update the species_guess
    species_guess = observation.species_guess
    if !taxon.blank? && !taxon.taxon_names.exists?(:name => species_guess)
      species_guess = nil
    end
    
    observation.skip_identifications = true
    observation.update_attributes(:species_guess => species_guess, :taxon => nil, :iconic_taxon_id => nil)
    ProjectUser.delay(:priority => INTEGRITY_PRIORITY).update_taxa_obs_and_observed_taxa_count_after_update_observation(observation.id, self.user_id)
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
    Identification.delay(:priority => INTEGRITY_PRIORITY).run_update_curator_identification(self)
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
  
  def expire_caches
    Identification.delay.expire_caches(self.id)
    true
  end

  def set_last_identification_as_current
    last_outdated = observation.identifications.outdated.by(user_id).order("id ASC").last
    if last_outdated
      Identification.update_all(["current = ?", true], ["id = ?", last_outdated])
    end
    true
  end
  
  # Revise the project_observation curator_identification_id if the
  # a curator's identification is deleted to be nil or that of another curator
  def revisit_curator_identification
    Identification.delay(:priority => INTEGRITY_PRIORITY).run_revisit_curator_identification(self.observation_id, self.user_id)
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
    !is_agreement?(options)
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
    current_ident = if ident.current?
      ident
    else
      obs.identifications.by(ident.user_id).current.order("id asc").last
    end
    obs.project_observations.each do |po|
      if current_ident.user.project_users.exists?(["project_id = ? AND role IN (?)", po.project_id, [ProjectUser::MANAGER, ProjectUser::CURATOR]])
        po.update_attributes(:curator_identification_id => current_ident.try(:id))
        ProjectUser.delay.update_observations_counter_cache_from_project_and_user(po.project_id, obs.user_id)
        ProjectUser.delay.update_taxa_counter_cache_from_project_and_user(po.project_id, obs.user_id)
        Project.delay.update_observed_taxa_count(po.project_id)
      end
    end
  end
  
  def self.run_revisit_curator_identification(observation_id, user_id)
    return unless obs = Observation.find_by_id(observation_id)
    return unless usr = User.find_by_id(user_id)
    obs.project_observations.each do |po|
      other_curator_conditions = ["project_id = ? AND role IN (?)", po.project_id, [ProjectUser::MANAGER, ProjectUser::CURATOR]]
      # The ident that was deleted is owned by user who is a curator of a project that that obs belongs to
      if usr.project_users.exists?(other_curator_conditions)
        other_curator_ident = nil

        # that project observation has other identifications that belong to users who are curators use those
        po.observation.identifications.current.each do |other_ident|
          if other_curator_ident = other_ident.user.project_users.exists?(other_curator_conditions)
            po.update_attributes(:curator_identification_id => other_ident.id)
            break
          end
        end

        po.update_attributes(:curator_identification_id => nil) unless other_curator_ident
        ProjectUser.delay.update_observations_counter_cache_from_project_and_user(po.project_id, obs.user_id)
        ProjectUser.delay.update_taxa_counter_cache_from_project_and_user(po.project_id, obs.user_id)
        Project.delay.update_observed_taxa_count(po.project_id)
      end
    end
  end

  def self.update_for_taxon_change(taxon_change, taxon, options = {})
    input_taxon_ids = taxon_change.input_taxa.map(&:id)
    scope = Identification.current.where("identifications.taxon_id IN (?)", input_taxon_ids).scoped
    scope = scope.where(:user_id => options[:user]) if options[:user]
    scope = scope.where("identifications.id IN (?)", options[:records]) unless options[:records].blank?
    scope = scope.where(options[:conditions]) if options[:conditions]
    scope = scope.includes(options[:include]) if options[:include]
    scope = scope.where("identifications.created_at < ?", Time.now)
    scope.find_each do |ident|
      new_ident = Identification.create(:observation => ident.observation, :taxon => taxon, 
        :user => ident.user, :taxon_change => taxon_change)
      yield(new_ident) if block_given?
    end
  end
  
  # /Static #################################################################
  
end
