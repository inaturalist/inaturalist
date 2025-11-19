# frozen_string_literal: true

class IdSummaryDqa < ApplicationRecord
  belongs_to :id_summary
  belongs_to :user

  PUBLIC_METRIC_QUESTIONS = {
    "true" => :true_statement?,
    "identification" => :useful_for_identification?,
    "references" => :backed_up_by_references?,
    "distinct" => :distinct_from_other_summaries?,
    "clear" => :short_colloquial_and_clearly_written?
  }.freeze
  PUBLIC_METRICS = PUBLIC_METRIC_QUESTIONS.keys
  PUBLIC_METRICS.each do | metric |
    const_set metric.upcase, metric
  end

  validates_presence_of :id_summary
  validates_inclusion_of :metric, in: PUBLIC_METRICS
  validates_uniqueness_of :metric, scope: [:id_summary_id, :user_id]
end
