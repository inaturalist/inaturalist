# frozen_string_literal: true

class ObservationGeoScore < ApplicationRecord
  belongs_to :observation
  validates_uniqueness_of :observation_id
end
