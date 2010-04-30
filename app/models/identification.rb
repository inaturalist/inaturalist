class Identification < ActiveRecord::Base
  acts_as_activity_streamable
  
  belongs_to :observation
  belongs_to :user
  belongs_to :taxon
  validates_presence_of :observation_id, :user_id
  validates_presence_of :taxon_id, 
                        :message => "for an ID must be something we recognize"
  validates_uniqueness_of :user_id, :scope => :observation_id, 
                          :message => "can only identify an observation once"
  
  after_create :update_observation, :increment_user_counter_cache, 
    :notify_observer
  after_save :update_obs_stats
  after_destroy :update_obs_stats, :decrement_user_counter_cache, 
    :update_observation_after_destroy
  
  
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

  # Update the observation if you're adding an ID to your own obs
  def update_observation
    return unless self.user_id == self.observation.user_id

    # update the species_guess
    species_guess = observation.species_guess
    unless taxon.taxon_names.exists?(:name => species_guess)
      species_guess = taxon.to_plain_s
    end
    Observation.update_all(
      ["taxon_id = ?, species_guess = ?, iconic_taxon_id = ?", taxon_id, species_guess, taxon.iconic_taxon_id],
      "id = #{observation_id}"
    )
    true
  end
  
  #
  # Tests whether this identification should be considered an agreement with
  # the observer's identification.  If this identification has the same taxon
  # or a child taxon of the observer's idnetification, then they agree.
  #
  def is_agreement?
    return false if self.observation.taxon.nil?
    return true if self.taxon_id == self.observation.taxon_id
    self.taxon.in_taxon? self.observation.taxon
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
  
  def notify_observer
    if self.observation.user_id != self.user_id && self.observation.user.preferences.identification_email_notification
      Emailer.send_later(:deliver_identification_notification, self)
    end
    true
  end
  
  protected
  
  #
  # Update the identification stats in the observation.
  #
  def update_obs_stats
    return true unless self.observation && self.observation.taxon_id
    
    idents = Identification.all(
      :conditions => ["observation_id = ?", self.observation_id]
    ).select {|ident| ident.user_id != self.observation.user_id}
    num_agreements = idents.select(&:is_agreement?).size
    num_disagreements = idents.reject(&:is_agreement?).size
    
    Observation.update_all(
      "num_identification_agreements = #{num_agreements}, " +
      "num_identification_disagreements = #{num_disagreements}", 
      "id = #{self.observation_id}")
    true
  end
  
  # Update the counter cache in users.  That cache ONLY tracks observations 
  # made for others.
  def increment_user_counter_cache
    if self.user_id != self.observation.user_id
      self.user.increment!(:identifications_count)
    end
    true
  end
  def decrement_user_counter_cache
    if self.user_id != self.observation.user_id
      self.user.decrement!(:identifications_count)
    end
    true
  end
  
  def update_observation_after_destroy
    return true unless self.observation.user_id == self.user_id
    
    # update the species_guess
    species_guess = self.observation.species_guess
    unless self.taxon.taxon_names.exists?(:name => species_guess)
      species_guess = nil
    end
    Observation.update_all(
      ["taxon_id = ?, species_guess = ?, iconic_taxon_id = ?", nil, species_guess, nil],
      "id = #{self.observation_id}"
    )
    true
  end
end
