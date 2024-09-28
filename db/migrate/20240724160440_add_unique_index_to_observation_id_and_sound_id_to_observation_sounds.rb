# frozen_string_literal: true

class AddUniqueIndexToObservationIdAndSoundIdToObservationSounds < ActiveRecord::Migration[6.1]
  def up
    sounds_with_duplicates = ObservationSound.group( :observation_id, :sound_id ).
      having( "count(*) > 1" ).count
    observation_ids_affected = []
    sounds_with_duplicates.each do | ids, _count |
      observation_id, sound_id = ids
      observation_ids_affected << observation_id
      duplicates = ObservationSound.where( observation_id: observation_id, sound_id: sound_id ).
        order( id: :asc ).offset( 1 )
      duplicates.each( &:destroy )
    end
    Observation.elastic_index!( ids: observation_ids_affected )
    add_index :observation_sounds, [:observation_id, :sound_id], unique: true
  end

  def down
    remove_index :observation_sounds, [:observation_id, :sound_id]
  end
end
