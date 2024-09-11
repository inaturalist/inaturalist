# frozen_string_literal: true

class AddColumnsToObservationAccuracySample < ActiveRecord::Migration[6.1]
  def change
    add_column :observation_accuracy_samples, :sounds_only, :boolean
    add_column :observation_accuracy_samples, :has_cid, :boolean
    add_column :observation_accuracy_samples, :captive, :boolean
    add_column :observation_accuracy_samples, :no_evidence, :boolean
    add_column :observation_accuracy_samples, :other_dqa_issue, :boolean
  end
end
