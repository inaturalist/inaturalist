# frozen_string_literal: true

class AddPostIdToObservationAccuracyExperiment < ActiveRecord::Migration[6.1]
  def change
    add_column :observation_accuracy_experiments, :post_id, :integer
  end
end
