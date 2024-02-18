# frozen_string_literal: true

class QualityMetric < ApplicationRecord
  blockable_by ->( qm ) { qm.observation.try( :user_id ) }

  belongs_to :user
  belongs_to :observation

  METRIC_QUESTIONS = {
    "wild" => :is_the_organism_wild,
    "location" => :does_the_location_seem_accurate,
    "date" => :does_the_date_seem_accurate,
    "evidence" => :evidence_of_organism?,
    "recent" => :recent_evidence?,
    "subject" => :evidence_related_to_single_subject?
  }.freeze
  METRICS = METRIC_QUESTIONS.keys
  METRICS.each do | metric |
    const_set metric.upcase, metric
  end

  after_save :update_observation
  after_destroy :update_observation

  validates_presence_of :observation
  validates_inclusion_of :metric, in: METRICS
  validates_uniqueness_of :metric, scope: [:observation_id, :user_id]
  validate :metric_can_be_assessed

  attr_accessor :wait_for_obs_index_refresh

  def to_s
    "<QualityMetric #{id} metric: #{metric}, user_id: #{user_id}, agree: #{agree}>"
  end

  def metric_can_be_assessed
    return true unless observation

    if metric == LOCATION && !observation.georeferenced?
      errors.add( :base, :no_votable_coordinates )
    end
    if metric == DATE && observation.observed_on.blank?
      errors.add( :base, :no_votable_date )
    end
    true
  end

  def update_observation
    return unless observation

    if ( o = Observation.find_by_id( observation_id ) )
      o.skip_quality_metrics = true
      o.wait_for_index_refresh ||= !wait_for_index_refresh.nil?
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

  def self.vote( user, observation, metric, agree )
    qm = observation.quality_metrics.find_or_initialize_by( metric: metric, user_id: user.try( :id ) )
    qm.update( agree: agree )
  end
end
