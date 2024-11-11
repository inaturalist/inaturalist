# frozen_string_literal: true

class ObservationAccuracyValidator < ApplicationRecord
  belongs_to :observation_accuracy_experiment
  belongs_to :user
  has_and_belongs_to_many :observation_accuracy_samples

  validates_uniqueness_of :user_id, scope: :observation_accuracy_experiment_id
end
