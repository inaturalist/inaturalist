class GoalParticipant < ActiveRecord::Base
  belongs_to :goal
  belongs_to :user
  has_many :goal_contributions
  
  validates_presence_of :goal_id, :user_id
  
  # ensure that a user only signs up to any goal once
  validates_uniqueness_of :goal_id,
                          :scope => :user_id
end
