class Photo < ActiveRecord::Base
  belongs_to :user
  has_and_belongs_to_many :observations
  has_and_belongs_to_many :taxa
  validates_presence_of :native_photo_id
  
  attr_accessor :api_response
  cattr_accessor :descendent_classes
  
  def validate
    if user.blank? && self.license == 0
      errors.add(
        :license, 
        "must be a Creative Commons license if the photo wasn't added by " +
        "an iNaturalist user using their linked Flickr account.")
    end
    
    # Check to make sure the user owns the flickr photo
    if self.user && self.api_response
      if self.api_response.is_a?(Net::Flickr::Photo)
        fp_flickr_user_id = self.api_response.owner
      else
        fp_flickr_user_id = self.api_response.owner.nsid
      end
      
      unless fp_flickr_user_id == self.user.flickr_identity.flickr_user_id
        errors.add(:user, "must own the photo on Flickr.")
      end
    end
  end
  
  # Return a string with attribution info about this photo
  def attribution
    case self.license
    when 0
      rights = '(c)'
    when nil
      rights = '(c)'
    when 7
      rights = '(o)'
    else
      rights = '(cc)'
    end
    
    if !self.native_realname.blank?
      name = self.native_realname
    elsif !self.native_username.blank?
      name = self.native_username
    elsif !self.observations.empty?
      name = self.observations.first.user.login
    else
      name = "anonymous Flickr user"
    end

    "#{rights} #{name}"
  end
  
  # Sync photo object with its native source.  Implemented by descendents
  def sync
    nil
  end
  
  # Retrieve info about a photo from its native source given its native id.  
  # Should be implemented by descendents
  def self.get_api_response(native_photo_id)
    nil
  end
  
  # Create a new Photo object from an API response.  Should be implemented by 
  # descendents
  def self.new_from_api_response(api_response, options = {})
    nil
  end
end