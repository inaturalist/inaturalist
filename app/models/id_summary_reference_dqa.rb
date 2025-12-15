# frozen_string_literal: true

class IdSummaryReferenceDqa < ApplicationRecord
  belongs_to :id_summary_reference
  belongs_to :user

  PUBLIC_METRIC_QUESTIONS = {
    "relevant" => :relevant_to_summary?,
    "true" => :true_statement?,
    "matches_taxon" => :refers_to_taxon?
  }.freeze
  PUBLIC_METRICS = PUBLIC_METRIC_QUESTIONS.keys
  PUBLIC_METRICS.each do | metric |
    const_set metric.upcase, metric
  end

  validates_presence_of :id_summary_reference
  validates_inclusion_of :metric, in: PUBLIC_METRICS
  validates_uniqueness_of :metric, scope: [:id_summary_reference_id, :user_id]
end
