class ObservationPhoto < ActiveRecord::Base
  belongs_to :observation
  belongs_to :photo
  
  after_create :set_observation_quality_grade
  after_destroy :destroy_orphan_photo, :set_observation_quality_grade
  
  def destroy_orphan_photo
    Photo.send_later(:destroy_orphans, photo_id)
    true
  end
  
  # Might be better to do this with DJ...
  def set_observation_quality_grade
    return true unless observation
    Observation.update_all(["quality_grade = ?", observation.get_quality_grade], ["id = ?", observation_id])
    true
  end
  
end
