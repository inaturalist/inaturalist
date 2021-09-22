class GoalContribution < ApplicationRecord
  belongs_to :contribution, :polymorphic => true
  belongs_to :goal_participant
  belongs_to :goal
  
  validates_presence_of :contribution_id, :goal_id, :goal_participant_id

  # Make sure the contribution is only contributing to any given goal once
  validates_uniqueness_of :contribution_id, 
                          :scope => [:goal_id, :contribution_type],
                          :message => "is already contributing to this goal"
  
  validate :goal_must_not_have_ended
  
  after_create :inform_goal_of_new_contribution
  
  # Allows goal contributions to be found by a particular goal id.
  #
  # Example:
  # GoalContribution.contributed_to(1).find(:all)
  scope :contributed_to, lambda {|goal_id| where('goal_id = ?', goal_id)}
  
  # Simple group by date, using the MySQL DATE function
  #
  # This doesn't seem to work in self.count calls, and so may be useless.
  scope :grouped_by_date, -> { group("DATE(created_at)") }
  
  # Accepts a start time and optional end time.  If no end time is provided,
  # assumes Time.now.  Note: this also works with Rails' additional Date
  # methods.
  #
  # Allows for complex date queries like so:
  # GoalContribution.contributed_to(1).within(7.days.ago).find(:all)
  # GoalContribution.contributed_to(1).within(1.hour.ago).find(:all)
  # GoalContribution.contributed_to(1).within(1.year.ago).find(:all)
  #
  # Using the Date methods:
  # GoalContribution.contributed_to(1).within(Date.today).find(:all)
  # GoalContribution.contributed_to(1).within(Date.yesterday).find(:all)
  scope :within, lambda {|*args|
    args[1] ||= Time.now
    {:conditions => ['created_at >= ? AND created_at <= ?', args[0], args[1]]}
  }
  
  # This is a magical bridge that tells the Goal object that a new
  # contribution has been made which may or may not play a part in the goal
  # being completed.
  def inform_goal_of_new_contribution
    self.goal.check_for_completion!(self.goal_participant)
  end
  
  protected
  
  ##### Validations #########################################################  
  # Used for a validation to ensure that goals which have already ended do not
  # continue to receive goal contributions.
  def goal_must_not_have_ended
    if self.goal.ended?
      errors.add(:goal, "has already ended")
    end
  end
end
