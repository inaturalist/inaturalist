class Photo < ActiveRecord::Base
  belongs_to :user
  has_many :observation_photos, :dependent => :destroy
  has_many :taxon_photos, :dependent => :destroy
  has_many :observations, :through => :observation_photos
  has_many :taxa, :through => :taxon_photos
  
  attr_accessor :api_response
  cattr_accessor :descendent_classes
  
  COPYRIGHT = 0
  NO_COPYRIGHT = 8
  
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
    rights = case self.license
    when COPYRIGHT, nil
      '(c)'
    when NO_COPYRIGHT
      '(o)'
    else
      '(cc)'
    end
    
    name = if !self.native_realname.blank?
      self.native_realname
    elsif !self.native_username.blank?
      self.native_username
    elsif !self.observations.empty?
      self.observations.first.user.login
    else
      "anonymous Flickr user"
    end

    "#{rights} #{name}"
  end
  
  # Sync photo object with its native source.  Implemented by descendents
  def sync
    nil
  end
  
  # Retrieve info about a photo from its native source given its native id.  
  # Should be implemented by descendents
  def self.get_api_response(native_photo_id, options = {})
    nil
  end
  
  # Create a new Photo object from an API response.  Should be implemented by 
  # descendents
  def self.new_from_api_response(api_response, options = {})
    nil
  end
  
  # Destroy a photo if it no longer belongs to any observations or taxa
  def self.destroy_orphans(ids)
    photos = Photo.all(:conditions => ["id IN (?)", [ids].flatten])
    return if photos.blank?
    photos.each do |photo|
      if !photo.observation_photos.exists? && !photo.taxon_photos.exists?
        photo.destroy
      end
    end
  end
  
end
