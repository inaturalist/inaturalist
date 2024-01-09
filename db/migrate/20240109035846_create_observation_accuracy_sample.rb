# frozen_string_literal: true

class CreateObservationAccuracySample < ActiveRecord::Migration[6.1]
  def change
    create_table :observation_accuracy_samples do | t |
      t.integer :observation_accuracy_experiment_id
      t.integer :observation_id
      t.integer :taxon_id
      t.string :quality_grade
      t.integer :year
      t.string :iconic_taxon_name
      t.string :continent
      t.integer :taxon_observations_count
      t.integer :taxon_rank_level
      t.integer :descendant_count

      t.timestamps
    end

    add_index :observation_accuracy_samples, :observation_accuracy_experiment_id,
      name: "index_oas_on_oae_id"
  end
end
