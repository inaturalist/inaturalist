class ObservationSound < ActiveRecord::Base
  belongs_to :observation, inverse_of: :observation_sounds, counter_cache: false
  belongs_to :sound
  after_create :set_observation_sounds_count
  after_destroy :set_observation_sounds_count

  def set_observation_sounds_count
    return true unless observation_id
    Observation.where(id: observation_id).update_all(
      observation_sounds_count: ObservationSound.where(observation_id: observation_id).count)
    true
  end
end
