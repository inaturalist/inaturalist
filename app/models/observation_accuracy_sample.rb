# frozen_string_literal: true

class ObservationAccuracySample < ApplicationRecord
  belongs_to :observation_accuracy_experiment
  belongs_to :observation
  has_and_belongs_to_many :observation_accuracy_validators
end
