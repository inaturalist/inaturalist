class QualityMetric < ActiveRecord::Base
  belongs_to :user
  belongs_to :observation
  
  METRIC_QUESTIONS = {
    "wild" => :is_the_organism_wild,
    "location" => :does_the_location_seem_accurate,
    "date" => :does_the_date_seem_accurate
  }
  METRICS = METRIC_QUESTIONS.keys
  METRICS.each do |metric|
    const_set metric.upcase, metric
  end
  
  after_save :set_observation_quality_grade
  after_destroy :set_observation_quality_grade
  
  validates_presence_of :observation
  validates_inclusion_of :metric, :in => METRICS
  validates_uniqueness_of :metric, :scope => [:observation_id, :user_id]
  
  def set_observation_quality_grade
    return true unless observation
    new_quality_grade = observation.get_quality_grade
    Observation.update_all(["quality_grade = ?", new_quality_grade], ["id = ?", observation_id])
    return true if Delayed::Job.where("handler LIKE '%CheckList%refresh_with_observation% #{observation.id}\n%'").exists?
    CheckList.delay(:priority => INTEGRITY_PRIORITY, :queue => "slow").refresh_with_observation(observation.id, 
      :taxon_id => observation.taxon_id)
    true
  end

  def self.vote(user, observation, metric, agree)
    qm = observation.quality_metrics.find_or_initialize_by_metric_and_user_id(metric, user.id)
    qm.update_attributes(:agree => agree)
  end
end
