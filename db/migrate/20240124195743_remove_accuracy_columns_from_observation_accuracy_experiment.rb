# frozen_string_literal: true

class RemoveAccuracyColumnsFromObservationAccuracyExperiment < ActiveRecord::Migration[6.1]
  def change
    remove_column :observation_accuracy_experiments, :low_acuracy_mean, :float
    remove_column :observation_accuracy_experiments, :low_acuracy_variance, :float
    remove_column :observation_accuracy_experiments, :high_accuracy_mean, :float
    remove_column :observation_accuracy_experiments, :high_accuracy_variance, :float
    remove_column :observation_accuracy_experiments, :precision_mean, :float
    remove_column :observation_accuracy_experiments, :precision_variance, :float
  end
end
