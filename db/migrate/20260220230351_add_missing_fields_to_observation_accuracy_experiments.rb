# frozen_string_literal: true

class AddMissingFieldsToObservationAccuracyExperiments < ActiveRecord::Migration[6.1]
  def change
    table = :observation_accuracy_experiments

    # integers
    add_column_unless_exists table, :sample_size, :integer
    add_column_unless_exists table, :taxon_id, :integer
    add_column_unless_exists table, :validator_redundancy_factor, :integer
    add_column_unless_exists table, :improving_id_threshold, :integer
    add_column_unless_exists table, :responding_validators, :integer
    add_column_unless_exists table, :validated_observations, :integer
    add_column_unless_exists table, :post_id, :integer

    # strings
    add_column_unless_exists table, :recent_window, :string
    add_column_unless_exists table, :validator_deadline_date, :string
    add_column_unless_exists table, :version, :string
    add_column_unless_exists table, :id_history_csv_path, :string
    add_column_unless_exists table, :sample_quality_filter, :string

    # datetimes
    add_column_unless_exists table, :sample_generation_date, :datetime
    add_column_unless_exists table, :validator_contact_date, :datetime
    add_column_unless_exists table, :assessment_date, :datetime

    # booleans
    add_column_unless_exists table, :consider_location, :boolean
    add_column_unless_exists table, :generate_sample_now, :boolean
    add_column_unless_exists table, :export_id_history_csv, :boolean
    add_column_unless_exists table, :id_history_improving_use_recent_window, :boolean
  end

  private

  def add_column_unless_exists( table, column, type, ** )
    return if column_exists?( table, column )

    add_column( table, column, type, ** )
  end
end
