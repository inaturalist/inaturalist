class QualityMetric < ActiveRecord::Base
  belongs_to :user
  belongs_to :observation
  
  METRIC_QUESTIONS = {
    "wild" => "Is the organism wild/naturalized?",
    "location" => "Does the location seem accurate?"
  }
  METRICS = METRIC_QUESTIONS.keys
  
  after_save :set_observation_quality_grade
  after_destroy :set_observation_quality_grade
  
  validates_presence_of :observation
  validates_inclusion_of :metric, :in => METRICS
  validates_uniqueness_of :metric, :scope => [:observation_id, :user_id]
  
  def set_observation_quality_grade
    return true unless observation
    Observation.update_all(["quality_grade = ?", observation.get_quality_grade], ["id = ?", observation_id])
    true
  end
end
