# frozen_string_literal: true

class FacebookPhoto < Photo
  validates_presence_of :native_photo_id
  validate :owned_by_user?

  PHOTO_FIELDS = "id,from,name,source,link,images"

  def owned_by_user?
    errors.add( :user, "doesn't own that photo" ) unless owned_by?( user )
  end

  def owned_by?( user )
    fbp_json = FacebookPhoto.get_api_response( native_photo_id, { user: user } )
    return false unless user && fbp_json
    return false if user.facebook_identity.blank? || ( fbp_json["from"]["id"] != user.facebook_identity.provider_uid )

    true
  end

  # facebook doesn't provide a square image
  # so for now, just return the thumbnail image
  def square_url
    thumb_url
  end

  def repair( _options = {} )
    raise "Not possible as of Spring 2023 since Facebook removed our access"
  end

  def self.repair( _find_options = {} )
    raise "Not possible as of Spring 2023 since Facebook removed our access"
  end

  def self.get_api_response( _native_photo_id, _options = {} )
    # Not possible as of Spring 2023 since Facebook removed our access
    nil
  end

  def self.new_from_api_response( _api_response, _options = {} )
    # Not possible as of Spring 2023 since Facebook removed our access
    nil
  end

  def to_observation
    fbp_json = api_response || FacebookPhoto.get_api_response( native_photo_id, user: user )
    return unless fbp_json

    observation = Observation.new
    observation.user = user if user
    observation.observation_photos.build( photo: self )
    observation.description = fbp_json["name"]
    observation.time_zone = observation.user.time_zone if observation.user
    observation
  end
end
