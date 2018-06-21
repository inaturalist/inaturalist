class ObservationPhoto < ActiveRecord::Base
  belongs_to :observation, :inverse_of => :observation_photos, :counter_cache => false
  belongs_to :photo

  validates_associated :photo
  validates_uniqueness_of :photo_id, scope: :observation_id
  validate :observer_owns_photo
  
  after_commit :set_observation_quality_grade,
               :set_observation_photos_count,
               on: :create
  after_destroy :destroy_orphan_photo, :set_observation_quality_grade, :set_observation_photos_count

  include Shared::TouchesObservationModule
  include ActsAsUUIDable

  def to_s
    "<ObservationPhoto #{id} observation_id: #{observation_id} photo_id: #{photo_id}>"
  end
  
  def destroy_orphan_photo
    Photo.delay(:priority => INTEGRITY_PRIORITY).destroy_orphans(photo_id)
    true
  end
  
  def set_observation_quality_grade
    return true unless observation
    return true if observation.new_record? # presumably this will happen when the obs is saved
    Observation.set_quality_grade( observation.id )
    true
  end

  def set_observation_photos_count
    return true unless observation_id
    Observation.where(id: observation_id).update_all(
      observation_photos_count: ObservationPhoto.where(:observation_id => observation_id).count)
    true
  end

  def observer_owns_photo
    unless observation.user_id == photo.user_id
      errors.add(:photo, "must be owned by the observer" )
    end
  end

end
