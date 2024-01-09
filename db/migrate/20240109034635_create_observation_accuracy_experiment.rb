# frozen_string_literal: true

class CreateObservationAccuracyExperiment < ActiveRecord::Migration[6.1]
  def change
    create_table :observation_accuracy_experiments do | t |
      t.integer :sample_size
      t.integer :validator_redundancy_factor
      t.datetime :sample_generation_date
      t.datetime :validator_contact_date
      t.datetime :validator_deadline_date
      t.datetime :assessment_date
      t.integer :validated_observations
      t.integer :low_acuracy_mean
      t.float :low_acuracy_mean
      t.float :low_acuracy_variance
      t.float :high_accuracy_mean
      t.float :high_accuracy_variance
      t.float :precision_mean
      t.float :precision_variance

      t.timestamps
    end
  end
end
