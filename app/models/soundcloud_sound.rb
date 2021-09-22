class SoundcloudSound < Sound
  
  LICENSE_MAPPINGS = {
    "all-rights-reserved" => 0,
    "cc-by-nc-sa" => 1,
    "cc-by-nc" => 2,
    "cc-by-nc-nd" => 3, 
    "cc-by" => 4,
    "cc-by-sa" => 5,
    "cc-by-nd" => 6,
    "no-rights-reserved" => 7
  }

  def self.client_for_user(user)
    return nil unless user && user.soundcloud_identity && user.soundcloud_identity.token
    Soundcloud.new(:access_token => user.soundcloud_identity.token)
    nil
  end

  def self.new_from_api_response(response)
    atts = {}
    atts[:native_username] = response.user.username
    atts[:native_sound_id] = response.id
    atts[:native_page_url] = response.permalink_url
    atts[:license] = LICENSE_MAPPINGS[response.license]
    atts[:native_response] = response.to_hash
    return self.new(atts)
  end

  def self.new_from_native_sound_id(sid, user)
    client = self.client_for_user(user)
    response = client.get("/tracks/#{sid}")
    sound = self.new_from_api_response(response)
    return sound
  end

  def secret_token
    self.native_response["secret_token"]
  end
  
  def to_observation
    # Setup the observation
    observation = Observation.new
    observation.user = self.user if self.user
    observation.sounds.build(self.attributes)
    observation.description = self.native_response["description"]
    if d = Chronic.parse(native_response['created_at'])
      observation.observed_on_string = d.in_time_zone(observation.user.time_zone || Time.zone).iso8601
    else
      observation.observed_on_string = self.native_response["created_at"]
    end
    observation.munge_observed_on_with_chronic
    observation.time_zone = observation.user.time_zone if observation.user
    
    # Try to get a taxon
    observation.taxon = to_taxon
    if t = observation.taxon
      observation.species_guess = t.common_name.try(:name) || t.name
    end

    observation
  end

  def to_taxa(options = {})
    return [] unless self.native_response && (tags_string = self.native_response["tag_list"]).present?

    # convert tag_string to an array of strings and handle multiword tags (which soundcloud puts in quotes)
    multiword_tags = tags_string.scan(/"[^"]+"/)
    multiword_tags.map do |t| 
      tags_string.gsub!(t, '') #remove from original set
      t.gsub!("\"",'') #clean up the quotes
    end
    tags = tags_string.split(' ') + multiword_tags

    tags << self.native_response["title"]

    # First try to find taxa matching taxonomic machine tags, then default 
    # to all tags
    machine_tags = tags.select{|t| t =~ /taxonomy\:/}
    taxa = Taxon.tags_to_taxa(machine_tags, options) unless machine_tags.blank?
    taxa ||= Taxon.tags_to_taxa(tags, options)
    taxa
    taxa.compact
  end

  # Return a *new* record with this one's attributes and the attached file
  def to_local_sound
    local_sound = LocalSound.new( attributes.reject{ |k,v| %w(id type).include?( k ) } )
    local_sound.subtype = self.class.name
    local_sound.file = StringIO.new( download.body )
    if filename = download.headers["content-disposition"][/\"(.+)\"/, 1]
      local_sound.file_file_name = filename
    end
    local_sound
  end

  # Convert existing to local sound and save
  def to_local_sound!
    local_sound = becomes( LocalSound )
    local_sound.subtype = self.class.name
    local_sound.file = StringIO.new( download.body )
    if filename = download.headers["content-disposition"][/\"(.+)\"/, 1]
      local_sound.file_file_name = filename
    end
    local_sound.save!
    Sound.where( id: id ).update_all( type: "LocalSound" )
    Sound.where( id: id ).first
  end

  def download
    unless @download_response
      if client = SoundcloudSound.client_for_user( user )
        api_response = client.get( "/tracks/#{native_sound_id}" )
        @download_response = client.get( api_response.download_url, allow_redirects: true )
      end
    end
    @download_response
  end

end