class ObservationPhoto < ActiveRecord::Base
  belongs_to :observation
  belongs_to :photo
  
  after_create :set_observation_quality_grade,
               :set_user_on_photo
  after_destroy :destroy_orphan_photo, :set_observation_quality_grade
  
  def destroy_orphan_photo
    Photo.send_later(:destroy_orphans, photo_id)
    true
  end
  
  # Might be better to do this with DJ...
  def set_observation_quality_grade
    return true unless observation
    Observation.send_later(:set_quality_grade, observation.id)
    true
  end
  
  def set_user_on_photo
    return true unless observation && photo
    Photo.update_all(["user_id = ?", observation.user_id], ["id = ?", photo.id])
    true
  end
  
end
