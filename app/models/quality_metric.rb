class QualityMetric < ActiveRecord::Base

  belongs_to :user
  belongs_to :observation
  
  METRIC_QUESTIONS = {
    "wild" => :is_the_organism_wild,
    "location" => :does_the_location_seem_accurate,
    "date" => :does_the_date_seem_accurate,
    "evidence" => :evidence_of_organism?,
    "recent" => :recent_evidence?
  }
  METRICS = METRIC_QUESTIONS.keys
  METRICS.each do |metric|
    const_set metric.upcase, metric
  end
  
  after_save :set_observation_quality_grade, :set_observation_captive,
    :set_observation_public_positional_accuracy, :set_observation_mappable,
    :elastic_index_observation
  after_destroy :set_observation_quality_grade, :set_observation_captive,
    :set_observation_public_positional_accuracy, :set_observation_mappable,
    :elastic_index_observation
  
  validates_presence_of :observation
  validates_inclusion_of :metric, :in => METRICS
  validates_uniqueness_of :metric, :scope => [:observation_id, :user_id]

  def to_s
    "<QualityMetric #{id} metric: #{metric}, user_id: #{user_id}, agree: #{agree}>"
  end
  
  def set_observation_quality_grade
    return true unless observation
    new_quality_grade = observation.get_quality_grade
    Rails.logger.debug "[DEBUG] setting obs quality grade to #{new_quality_grade}"
    Observation.where(id: observation_id).update_all(quality_grade: new_quality_grade)
    CheckList.delay(priority: INTEGRITY_PRIORITY, queue: "slow",
      unique_hash: { "CheckList::refresh_with_observation": observation.id}).
      refresh_with_observation(observation.id, :taxon_id => observation.taxon_id)
    true
  end

  def set_observation_captive
    return true unless observation
    observation.reload.set_captive
    true
  end

  def set_observation_public_positional_accuracy
    return true unless observation
    observation.reload.update_public_positional_accuracy
    true
  end

  def set_observation_mappable
    return true unless observation
    observation.reload.update_mappable
    true
  end

  def elastic_index_observation
    Rails.logger.debug "[DEBUG] indexing obs, quality: #{observation.quality_grade}"
    observation.elastic_index!
  end

  def self.vote(user, observation, metric, agree)
    qm = observation.quality_metrics.find_or_initialize_by(metric: metric, user_id: user.id)
    qm.update_attributes(:agree => agree)
  end
end
