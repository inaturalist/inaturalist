class QualityMetric < ActiveRecord::Base
  belongs_to :user
  belongs_to :observation
  
  METRIC_QUESTIONS = {
    "wild" => "Is the organism wild/naturalized?",
    "location" => "Does the location seem accurate?"
  }
  METRICS = METRIC_QUESTIONS.keys
  
  validates_presence_of :observation
  validates_inclusion_of :metric, :in => METRICS
  validates_uniqueness_of :metric, :scope => [:observation_id, :user_id]
end
