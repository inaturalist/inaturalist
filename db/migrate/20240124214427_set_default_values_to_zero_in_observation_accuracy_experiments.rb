# frozen_string_literal: true

class SetDefaultValuesToZeroInObservationAccuracyExperiments < ActiveRecord::Migration[6.1]
  def change
    change_column_default( :observation_accuracy_experiments, :responding_validators, 0 )
    change_column_default( :observation_accuracy_experiments, :validated_observations, 0 )
  end
end
