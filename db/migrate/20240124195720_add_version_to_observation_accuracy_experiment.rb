# frozen_string_literal: true

class AddVersionToObservationAccuracyExperiment < ActiveRecord::Migration[6.1]
  def change
    add_column :observation_accuracy_experiments, :version, :string
  end
end
