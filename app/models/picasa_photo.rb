class PicasaPhoto < Photo
  def validate
    if user.blank? && self.license == 0
      errors.add(
        :license, 
        "must be a Creative Commons license if the photo wasn't added by " +
        "an iNaturalist user using their linked Picasa account.")
    end
    
    # Check to make sure the user owns the flickr photo
    if self.user && self.api_response
      picasa_user_id = self.api_response.user if self.api_response.is_a?(Picasa::Photo)
      
      unless picasa_user_id == self.user.picasa_identity.picasa_user_id
        errors.add(:user, "must own the photo on Picasa.")
      end
    end
  end
  
  # TODO Sync photo object with its native source.
  def sync
    nil
  end
  
  # TODO Retrieve info about a photo from its native source given its native id.  
  def self.get_api_response(native_photo_id)
    nil
  end
  
  # TODO Create a new Photo object from an API response.
  def self.new_from_api_response(api_response, options = {})
    nil
  end
end
