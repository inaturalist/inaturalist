class Goal < ActiveRecord::Base
  has_many :goal_rules,
           :dependent => :destroy
  has_many :goal_participants,
           :dependent => :destroy
  has_many :goal_contributions,
           :dependent => :destroy
  has_many :users,
           :through => :goal_participants
  
  validates_presence_of :goal_type
  
  validate :must_end_in_the_future
  
  after_create :create_community_goal_participants

  # finder to allow Goal.for('community').find queries
  scope :for, lambda {|type| where('goal_type = ?', type)}
  
  # This finder is really only applicable to community goals.
  # Individual goals are 'completed' by the number of individual
  # contributions the person puts into a goal, so this is pretty meaningless
  # because those queries come from the perspective of the user, not the goal.
  scope :incomplete, -> { where('completed = 0 AND (ends_at IS NULL OR ends_at > ?)', Time.now) }

  
  # Most goals will be individual goals, however some, like our initial
  # goal of 5,000 observations can be community based.  Because of that,
  # the goal should be able to check for itself to see if it is completed,
  # and if it is, and it's a community goal, it notes it to itself.  If it is
  # completed and it is an individual goal, it notes it to the 
  # goal_participant object
  def check_for_completion!(goal_participant=nil)
    case self.goal_type
      when 'community'
        contribution_count = self.goal_contributions.count
        if contribution_count >= self.number_of_contributions_required.to_i
          self.completed = true
          self.save
        end
      when 'individual'
        if goal_participant.nil?
          raise "Must provide a goal contribution object when checking individual goal completions"
        end
        completed = goal_participant.goal_contributions.count
        if self.number_of_contributions_required.to_i <= completed
          goal_participant.goal_completed = true
          goal_participant.save
        end
    end
  end
  
  # Watch out for this!
  # This might run very slowly when there are a bazzillion inaturaslits, but
  # it should work for now.
  def create_community_goal_participants
    if self.goal_type == 'community'
      self.users << User.find(:all)
    end
  end
  
  # checks to see if the goal has ended __NOT__ completed!
  def ended?
    return false if self.ends_at.nil?
    self.ends_at < Time.now
  end
  
  def must_end_in_the_future
    if self.ended?
      errors.add(:ends_at, "must be in the future")
    end
  end
  
  # Receives thing, marshals all of the rules associated with itself, and
  # runs through them one by one.  If thing passes all the rules,
  # #passes_all_rules? returns true.
  #
  # Right now this represents a simple model whereby each object is tested
  # against each rule.  It might make more sense to only test each object
  # against the rules which share the same class.  Otherwise each rule
  # must handle all types of objects for them to be reusable.
  #
  # For example, we test an observation against 2 rules, one in the 
  # Observation class that sees if the observation was recorded before a
  # certain date, an another in the Taxon class that sees if a species
  # is found in a taxon. The rule within the Taxon class might expect to be
  # passed a Taxon object, but will receive an Observation object.  This
  # means that either the method will return false, the method should return
  # nothing (nil) or the method should handle Observation objects as well as
  # Taxon objects.  For now I think we should let this play out and keep an
  # eye on it.
  def rules_validate_against?(thing)
    return false if self.goal_rules.size == 0
    !self.goal_rules.map{ |rule| rule.validates?(thing) }.include?(false)
  end
  
  # This method is built up upon the rules_validate_against? method and
  # records a GoalContribution if it is valid. This assumes that 'thing' has a
  # polymorphic relationship to GoalContribution..
  def validate_and_add_contribution(thing, goal_participant)
    if self.rules_validate_against?(thing)
      logger.debug "[DEBUG] #{self} rules validates against #{thing}"
      gc = GoalContribution.new({
        :goal_id             => self.id,
        :goal_participant_id => goal_participant.id,
        :contribution => thing
      })
      if gc.valid?
        thing.goal_contributions << gc
      else
        logger.debug "[DEBUG] Failed to save goal contribution #{gc}: #{gc.errors.full_messages}"
      end
      return thing
    end
    false
  end
end
