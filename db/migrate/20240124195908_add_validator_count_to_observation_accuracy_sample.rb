# frozen_string_literal: true

class AddValidatorCountToObservationAccuracySample < ActiveRecord::Migration[6.1]
  def change
    add_column :observation_accuracy_samples, :validator_count, :integer
  end
end
