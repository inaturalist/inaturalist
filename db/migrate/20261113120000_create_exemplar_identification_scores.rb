# frozen_string_literal: true

class CreateExemplarIdentificationScores < ActiveRecord::Migration[6.1]
  def change
    create_table :exemplar_identification_scores do | t |
      t.bigint :exemplar_identification_id, null: false
      t.string :status, null: false
      t.integer :self_contained_score, limit: 2
      t.integer :self_contained_vote_sum, limit: 2
      t.integer :readability_score, limit: 2
      t.integer :readability_vote_sum, limit: 2
      t.integer :id_help_score, limit: 2
      t.integer :id_help_vote_sum, limit: 2
      t.integer :cool_fact_score, limit: 2
      t.integer :cool_fact_vote_sum, limit: 2
      t.text :flags, array: true, null: false, default: []
      t.json :raw_votes
      t.string :filter_model
      t.string :score_model
      t.string :prompt_version
      t.datetime :scored_at
      t.integer :attempts, limit: 2, null: false, default: 0
      t.text :last_error
      t.datetime :last_attempt_at
      t.timestamps
    end

    add_index :exemplar_identification_scores, :exemplar_identification_id,
      unique: true,
      name: "index_exemplar_identification_scores_on_exemplar_id"
    add_index :exemplar_identification_scores, :status,
      where: "status IN ('pending', 'submitted')",
      name: "index_exemplar_identification_scores_on_backlog_status"
  end
end
