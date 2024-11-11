# frozen_string_literal: true

class ObservationPhoto < ApplicationRecord
  belongs_to_with_uuid :observation, inverse_of: :observation_photos, counter_cache: false
  belongs_to :photo

  validates :photo, presence: true
  validates :observation, presence: true
  validates_associated :photo
  validates_uniqueness_of :photo_id, scope: :observation_id
  validate :observer_owns_photo

  after_commit :set_observation_quality_grade,
    :set_observation_photos_count,
    on: :create
  after_destroy :destroy_orphan_photo, :set_observation_quality_grade,
    :set_observation_photos_count

  include Shared::TouchesObservationModule
  include ActsAsUUIDable
  include LogsDestruction

  def to_s
    "<ObservationPhoto #{id} observation_id: #{observation_id} photo_id: #{photo_id}>"
  end

  def destroy_orphan_photo
    Photo.delay( priority: INTEGRITY_PRIORITY ).destroy_orphans( photo_id )
    true
  end

  def set_observation_quality_grade
    return true unless observation
    return true if observation.bulk_delete

    # presumably this will happen when the obs is saved
    return true if observation.new_record?

    # If the observation will be saved after this record is created, setting
    # quality grade should also not be necessary
    return true if observation.will_be_saved_with_photos

    # For some reason the observation's after_commit callbacks seem to fire
    # after the ObservationPhoto is saved, so if you don't set the quality_grade
    # on this instance of the observation, it will fail to index properly
    observation.quality_grade = Observation.set_quality_grade( observation.id )
    true
  end

  def set_observation_photos_count
    return true unless observation_id
    return true if observation.bulk_delete

    Observation.where( id: observation_id ).update_all(
      observation_photos_count: ObservationPhoto.where( observation_id: observation_id ).count
    )
    true
  end

  def observer_owns_photo
    return unless observation && photo
    return if observation.user_id == photo.user_id

    errors.add( :photo, "must be owned by the observer" )
  end
end
