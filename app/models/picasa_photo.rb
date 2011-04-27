class PicasaPhoto < Photo
  
  Photo.descendent_classes ||= []
  Photo.descendent_classes << self
  
  validates_presence_of :native_photo_id
  
  def validate
    if user.blank? && self.license == 0
      errors.add(
        :license, 
        "must be a Creative Commons license if the photo wasn't added by " +
        "an iNaturalist user using their linked Picasa account.")
    end
    
    # Check to make sure the user owns the flickr photo
    if self.user
      unless native_username == self.user.picasa_identity.picasa_user_id
        errors.add(:user, "must own the photo on Picasa.")
      end
    end
  end
  
  # TODO Sync photo object with its native source.
  def sync
    nil
  end
  
  def to_observation  
    self.api_response ||= PicasaPhoto.get_api_response(self.native_photo_id, :user => self.user)
    
    # Setup the observation
    observation = Observation.new
    observation.user = self.user if self.user
    observation.photos << self
    observation.description = api_response.description
    if timestamp = api_response.exif_time || api_response.timestamp
      observation.observed_on_string = Time.at(timestamp / 1000).to_s(:long)
    end
    observation.munge_observed_on_with_chronic
    observation.time_zone = observation.user.time_zone if observation.user
    
    # Get the geo fields
    if api_response.point
      observation.latitude = api_response.point.lat
      observation.longitude = api_response.point.lng
    end
    observation.place_guess = api_response.location
    if observation.place_guess.blank? && api_response.point
      latrads = observation.latitude.to_f * (Math::PI / 180)
      lonrads = observation.longitude.to_f * (Math::PI / 180)
      places = Place.search(:geo => [latrads,lonrads], :order => "@geodist asc", :limit => 5) rescue []
      places = places.compact.select {|p| p.contains_lat_lng?(observation.latitude, observation.longitude)}
      places = places.sort_by(&:bbox_area)
      # if place = Place.containing_lat_lng(observation.latitude, observation.longitude).first(:order => "bbox_area ASC")
      #   observation.place_guess = place.display_name
      # end
      if place = places.first
        observation.place_guess = place.display_name
      end
    end
    
    # Try to get a taxon
    photo_taxa = to_taxa
    unless photo_taxa.blank?
      observation.taxon = photo_taxa.detect(&:species_or_lower?)
      observation.taxon ||= photo_taxa.first
      
      if observation.taxon
        begin
          observation.species_guess = observation.taxon.common_name.name
        rescue
          observation.species_guess = observation.taxon.name
        end
      end
    end

    observation
  end
  
  def to_taxa
    self.api_response ||= PicasaPhoto.get_api_response(self.native_photo_id, :user => self.user)
    Taxon.tags_to_taxa(api_response.keywords.split(',').map(&:strip)) unless api_response.keywords.blank?
  end
  
  # TODO Retrieve info about a photo from its native source given its native id.  
  def self.get_api_response(native_photo_id, options = {})
    # Picasa API calls only work with a user's token, so first we try to get 
    # a PicasaIdentity from a passed in user, then we try to parse one out of 
    # the native ID (which should be a URL)
    picasa_identity = if options[:user]
      picasa_identity = options[:user].picasa_identity
    elsif native_photo_id.is_a?(String) && matches = native_photo_id.match(/user\/(.+?)\//)
      picasa_identity = PicasaIdentify.find_by_picasa_user_id(matches[1])
    else
      nil
    end
    
    if picasa_identity
      picasa = Picasa.new(picasa_identity.token)
      return picasa.get_url(native_photo_id, :kind => "photo,user", :thumbsize => RubyPicasa::Photo::VALID.join(','))
    end

    nil
  end
  
  # TODO Create a new Photo object from an API response.
  def self.new_from_api_response(api_response, options = {})
    if api_response.author
      native_username = api_response.author.user
      native_realname = api_response.author.nickname
    else
      native_username = api_response.user
      native_realname = api_response.nickname
    end
    options.update(
      :user            => options[:user],
      :native_photo_id => api_response.link('self').href,
      :square_url      => api_response.url('72c'),
      :thumb_url       => api_response.url('110'),
      :small_url       => api_response.url('220'),
      :medium_url      => api_response.url('512'),
      :large_url       => api_response.url('1024'),
      :original_url    => api_response.url,
      :native_page_url => api_response.link('alternate').href,
      :native_username => native_username,
      :native_realname => native_realname,
      :license         => api_response.license || 0
    )
    picasa_photo = PicasaPhoto.new(options)
    if !picasa_photo.native_username && matches = picasa_photo.native_photo_id.match(/user\/(.+?)\//)
      picasa_photo.native_username = matches[1]
    end
    picasa_photo.api_response = api_response
    picasa_photo
  end
end
