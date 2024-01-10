# frozen_string_literal: true

class CreateJoinTableObservationAccuracySamplesObservationAccuracyValidators < ActiveRecord::Migration[6.1]
  def change
    create_join_table :observation_accuracy_samples, :observation_accuracy_validators do | t |
      t.index  \
        [:observation_accuracy_sample_id, :observation_accuracy_validator_id], name: "index_oa_samples_oa_validators"
      t.index  \
        [:observation_accuracy_validator_id, :observation_accuracy_sample_id], name: "index_oa_validators_oa_samples"
    end
  end
end
