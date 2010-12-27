class ObservationPhoto < ActiveRecord::Base
  belongs_to :observation
  belongs_to :photo
  
  after_destroy :destroy_orphan_photo
  
  def destroy_orphan_photo
    Photo.send_later(:destroy_orphan, photo_id)
    true
  end
  
end