class ObservationPhoto < ActiveRecord::Base
  belongs_to :observation
  belongs_to :photo
  
  after_create :set_observation_quality_grade,
               :set_user_on_photo,
               :set_observation_photos_count
  after_destroy :destroy_orphan_photo, :set_observation_quality_grade, :set_observation_photos_count
  
  def destroy_orphan_photo
    Photo.delay.destroy_orphans(photo_id)
    true
  end
  
  # Might be better to do this with DJ...
  def set_observation_quality_grade
    return true unless observation
    Observation.delay.set_quality_grade(observation.id)
    true
  end
  
  def set_user_on_photo
    return true unless observation && photo
    Photo.update_all(["user_id = ?", observation.user_id], ["id = ?", photo.id])
    true
  end

  def set_observation_photos_count
    Observation.update_all(["photos_count = ?", observation.observation_photos(:reload => true).count], ["id = ?", observation])
    true
  end
  
end
