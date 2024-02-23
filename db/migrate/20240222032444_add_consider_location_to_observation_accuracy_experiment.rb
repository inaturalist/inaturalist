# frozen_string_literal: true

class AddConsiderLocationToObservationAccuracyExperiment < ActiveRecord::Migration[6.1]
  def change
    add_column :observation_accuracy_experiments, :consider_location, :boolean, default: false
  end
end
