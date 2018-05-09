class ObservationSound < ActiveRecord::Base
  belongs_to :observation, inverse_of: :observation_sounds, counter_cache: false
  belongs_to :sound
  after_create :set_observation_sounds_count
  after_destroy :set_observation_sounds_count
  after_destroy :destroy_orphan_sound

  include Shared::TouchesObservationModule
  include ActsAsUUIDable

  def set_observation_sounds_count
    return true unless observation_id
    Observation.where(id: observation_id).update_all(
      observation_sounds_count: ObservationSound.where(observation_id: observation_id).count)
    true
  end

  def serializable_hash( opts = nil )
    {
      id: id,
      uuid: uuid,
      created_at: created_at,
      updated_at: updated_at,
      sound: sound.as_indexed_json
    }
  end

  private
  def destroy_orphan_sound
    Sound.delay( priority: INTEGRITY_PRIORITY ).destroy_orphans( sound_id )
    true
  end
end
