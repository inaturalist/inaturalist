class ObservationPhoto < ActiveRecord::Base
  belongs_to :observation, :inverse_of => :observation_photos, :counter_cache => false
  belongs_to :photo

  validates_associated :photo
  validates_uniqueness_of :photo_id, :scope => :observation_id
  
  after_create :set_observation_quality_grade,
               :set_observation_photos_count
  after_destroy :destroy_orphan_photo, :set_observation_quality_grade, :set_observation_photos_count

  include Shared::TouchesObservationModule

  def to_s
    "<ObservationPhoto #{id} observation_id: #{observation_id} photo_id: #{photo_id}>"
  end
  
  def destroy_orphan_photo
    Photo.delay(:priority => INTEGRITY_PRIORITY).destroy_orphans(photo_id)
    true
  end
  
  # Might be better to do this with DJ...
  def set_observation_quality_grade
    return true unless observation
    Observation.delay.set_quality_grade(observation.id)
    true
  end

  def set_observation_photos_count
    return true unless observation_id
    Observation.where(id: observation_id).update_all(
      observation_photos_count: ObservationPhoto.where(:observation_id => observation_id).count)
    true
  end
  
end
