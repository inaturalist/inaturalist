# frozen_string_literal: true

class AddValidationCountToObservationAccuracyValidator < ActiveRecord::Migration[6.1]
  def change
    add_column :observation_accuracy_validators, :validation_count, :integer
  end
end
