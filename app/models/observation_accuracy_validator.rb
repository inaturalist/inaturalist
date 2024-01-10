# frozen_string_literal: true

class ObservationAccuracyValidator < ApplicationRecord
  belongs_to :user
  has_and_belongs_to_many :observation_accuracy_samples
end
