class ObservationSound < ApplicationRecord
  belongs_to_with_uuid :observation, inverse_of: :observation_sounds, counter_cache: false
  belongs_to :sound
  after_create :set_observation_sounds_count, :set_observation_quality_grade
  after_destroy :set_observation_sounds_count, :set_observation_quality_grade
  after_destroy :destroy_orphan_sound

  include Shared::TouchesObservationModule
  include ActsAsUUIDable

  def set_observation_quality_grade
    return true unless observation
    return true if observation.new_record? # presumably this will happen when the obs is saved
    Observation.set_quality_grade( observation.id )
    true
  end

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
