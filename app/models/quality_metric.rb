class QualityMetric < ActiveRecord::Base

  blockable_by lambda {|qm| qm.observation.user_id }

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
  
  after_save :update_observation
  after_destroy :update_observation
  
  validates_presence_of :observation
  validates_inclusion_of :metric, :in => METRICS
  validates_uniqueness_of :metric, :scope => [:observation_id, :user_id]

  def to_s
    "<QualityMetric #{id} metric: #{metric}, user_id: #{user_id}, agree: #{agree}>"
  end

  def update_observation
    return unless observation
    if o = Observation.find_by_id( observation_id )
      o.skip_quality_metrics = true
      o.save
    end
    true
  end

  def as_indexed_json
    {
      id: id,
      user_id: user_id,
      metric: metric,
      agree: agree
    }
  end

  def self.vote(user, observation, metric, agree)
    UpdateAction.__elasticsearch__.refresh_index!
    qm = observation.quality_metrics.find_or_initialize_by( metric: metric, user_id: user.try(:id) )
    qm.update_attributes( agree: agree )
  end
end
