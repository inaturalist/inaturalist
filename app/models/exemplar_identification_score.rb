# frozen_string_literal: true

# Scores of an exemplar identification's body, and where it stands in the
# scoring run. One row per exemplar identification.
class ExemplarIdentificationScore < ApplicationRecord
  belongs_to :exemplar_identification

  PENDING = "pending"
  ON_HOLD = "on_hold"
  SUBMITTED = "submitted"
  SCORED = "scored"
  FAILED = "failed"
  FILTERED_UNCERTAIN = "filtered_uncertain"
  FILTERED_NO_VALUE = "filtered_no_value"
  SKIPPED_SHORT = "skipped_short"
  # Only set by the initial run (July 2026), which skipped bodies whose text
  # appeared on 10 or more taxa. Later runs don't check for duplicates
  SKIPPED_DUPLICATE = "skipped_duplicate"
  STATUSES = [
    PENDING,
    ON_HOLD,
    SUBMITTED,
    SCORED,
    FAILED,
    FILTERED_UNCERTAIN,
    FILTERED_NO_VALUE,
    SKIPPED_SHORT,
    SKIPPED_DUPLICATE
  ].freeze

  RESULT_ATTRIBUTES = %w(
    self_contained_score
    self_contained_vote_sum
    readability_score
    readability_vote_sum
    id_help_score
    id_help_vote_sum
    cool_fact_score
    cool_fact_vote_sum
    raw_votes
    filter_model
    score_model
    prompt_version
    scored_at
  ).freeze

  validates :status, inclusion: { in: STATUSES }
end
