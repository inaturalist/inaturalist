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
    new_quality_grade = observation.get_quality_grade
    Observation.update_all(["quality_grade = ?", new_quality_grade], ["id = ?", observation_id])
    if new_quality_grade != observation.quality_grade
      CheckList.send_later(:refresh_with_observation, observation.id, 
        :taxon_id => observation.taxon_id, 
        :skip_update => true,
        :dj_priority => 1)
    end
    true
  end
  
  def set_user_on_photo
    return true unless observation && photo
    Photo.update_all(["user_id = ?", observation.user_id], ["id = ?", photo.id])
    true
  end
  
end
