# frozen_string_literal: true

class IdSummaryDqa < ApplicationRecord
  belongs_to :id_summary
  belongs_to :user

  STAFF_METRIC_QUESTIONS = {
    "metric1" => :metric1,
    "metric2" => :metric2
  }.freeze
  PUBLIC_METRIC_QUESTIONS = {
    "true" => :true_statement?,
    "identification" => :useful_for_identification?,
    "references" => :backed_up_by_references?,
    "distinct" => :distinct_from_other_summaries?,
    "clear" => :short_colloquial_and_clearly_written?
  }.freeze
  STAFF_METRICS = STAFF_METRIC_QUESTIONS.keys
  STAFF_METRICS.each do | metric |
    const_set metric.upcase, metric
  end
  PUBLIC_METRICS = PUBLIC_METRIC_QUESTIONS.keys
  PUBLIC_METRICS.each do | metric |
    const_set metric.upcase, metric
  end
  ALL_METRICS = ( STAFF_METRICS | PUBLIC_METRICS ).freeze

  validates_presence_of :id_summary
  validates_inclusion_of :metric, in: ALL_METRICS
  validates_uniqueness_of :metric, scope: [:id_summary_id, :user_id]
  validate :metric_can_be_assessed

  def metric_can_be_assessed
    # Test user is staff for some metrics
    true
  end
end
