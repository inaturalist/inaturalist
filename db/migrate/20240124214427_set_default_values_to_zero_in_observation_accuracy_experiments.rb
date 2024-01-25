# frozen_string_literal: true

class SetDefaultValuesToZeroInObservationAccuracyExperiments < ActiveRecord::Migration[6.1]
  def change
    change_column_default( :observation_accuracy_experiments, :responding_validators, from: nil, to: 0 )
    change_column_default( :observation_accuracy_experiments, :validated_observations, from: nil, to: 0 )
  end
end
