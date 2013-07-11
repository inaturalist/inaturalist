class ObservationSound < ActiveRecord::Base
  belongs_to :observation, :inverse_of => :observation_sounds, :counter_cache => false
  belongs_to :sound
  after_create :set_observation_sounds_count
  after_destroy :set_observation_sounds_count

  def set_observation_sounds_count
    if o = Observation.find_by_id(observation_id)
      Observation.update_all(["sounds_count = ?", o.observation_sounds.count], ["id = ?", o.id])
    end
    true
  end
end