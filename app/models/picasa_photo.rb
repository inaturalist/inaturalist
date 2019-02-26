#encoding: utf-8
class PicasaPhoto < Photo
  validates_presence_of :native_photo_id
  validate :licensed_if_no_user
  
  # TODO Sync photo object with its native source.
  def sync
    nil
  end
  
  def to_observation  
    self.api_response ||= PicasaPhoto.get_api_response(self.native_photo_id, :user => self.user)
    
    # Setup the observation
    observation = Observation.new
    observation.user = self.user if self.user
    observation.observation_photos.build(:photo => self, :observation => observation)
    observation.description = api_response["description"]
    if timestamp = api_response["creationTime"]
      # Google seems to present these as UTC these days (I think)
      observation.observed_on_string = ActiveSupport::TimeZone.new('UTC').at(timestamp / 1000).to_s(:long)
    end
    observation.munge_observed_on_with_chronic
    observation.time_zone = observation.user.time_zone if observation.user
    
    # As of Feb 2019, the Picasa API went away and was replaced with the Google
    # Photos API, which doesn't return any geodata
    
    # Try to get a taxon
    observation.taxon = to_taxon
    if t = observation.taxon
      observation.species_guess = t.common_name.try(:name) || t.name
    end

    observation
  end
  
  def to_taxa(options = {})
    # As of Feb 2019, the Picasa API went away and was replaced with the Google
    # Photos API, which doesn't return any text aside from this description
    Taxon.tags_to_taxa([api_response["description"].to_s.strip], options)
  end

  def repair(options = {})
    unless r = PicasaPhoto.get_api_response(native_photo_id, :user => user)
      return [self, {
        :failed => "Failed to load Picasa photo"
      }]
    end
    self.square_url = "#{r["baseUrl"]}=w75-h75-c"
    self.thumb_url = "#{r["baseUrl"]}=w100-h100"
    self.small_url = "#{r["baseUrl"]}=w240-h240"
    self.medium_url = "#{r["baseUrl"]}=w500-h500"
    self.large_url = "#{r["baseUrl"]}=w1024-h1024"
    self.original_url = "#{r["baseUrl"]}=d"
    self.native_page_url = r["productUrl"]
    save unless options[:no_save]
    [self, {}]
  end

  def self.repair(find_options = {})
    puts "[INFO #{Time.now}] starting PicasaPhoto.repair, options: #{find_options.inspect}"
    find_options[:include] ||= [:user, :taxon_photos, :observation_photos]
    find_options[:batch_size] ||= 100
    find_options[:sleep] ||= 10
    updated = 0
    destroyed = 0
    invalids = 0
    skipped = 0
    start_time = Time.now
    PicasaPhoto.where(find_options).find_each do |p|
      r = Net::HTTP.get_response(URI.parse(p.medium_url))
      unless [Net::HTTPBadRequest, Net::HTTPForbidden, Net::HTTPRedirection].include?(r.code_type)
        skipped += 1
        next
      end
      repaired, errors = p.repair
      if errors.blank?
        updated += 1
      else
        puts "[ERROR] #{errors.values.to_sentence}"
        if repaired.frozen?
          destroyed += 1 
          puts "[ERROR] destroyed #{repaired}"
        end
        if errors[:picasa_account_not_linked]
          invalids += 1
          puts "[ERROR] Picasa account not linked for #{repaired}"
        end
      end
    end
    puts "[INFO #{Time.now}] finished PicasaPhoto.repair, #{updated} updated, #{destroyed} destroyed, #{invalids} invalid, #{skipped} skipped, #{Time.now - start_time}s"
  end
  
  # Retrieve info about a photo from its native source given its native id.  
  def self.get_api_response(native_photo_id, options = {})
    # Picasa API calls only work with a user's token, so first we try to get 
    # a PicasaIdentity from a passed in user, then we try to parse one out of 
    # the native ID (which should be a URL)
    picasa_identity = if options[:user]
      options[:user].picasa_identity
    elsif native_photo_id.is_a?(String) && matches = native_photo_id.match(/user\/(.+?)\//)
      User.find_by_id(matches[1]).try(:picasa_identity)
    else
      nil
    end
    
    if picasa_identity
      PicasaPhoto.picasa_request_with_refresh( picasa_identity ) do
        goog = GooglePhotosApi.new( picasa_identity.token )
        goog.media_item( native_photo_id )
      end
    else
      nil
    end
  end
  
  # Create a new Photo object from an API response.
  def self.new_from_api_response(api_response, options = {})
    options = options.dup
    options[:native_photo_id] = api_response["id"]
    options[:square_url] = "#{api_response["baseUrl"]}=w75-h75-c"
    options[:thumb_url] = "#{api_response["baseUrl"]}=w100-h100"
    options[:small_url] = "#{api_response["baseUrl"]}=w240-h240"
    options[:medium_url] = "#{api_response["baseUrl"]}=w500-h500"
    options[:large_url] = "#{api_response["baseUrl"]}=w1024-h1024"
    options[:original_url] = "#{api_response["baseUrl"]}=d"
    options[:native_page_url] = api_response["productUrl"]
    picasa_photo = PicasaPhoto.new( options )
    picasa_photo.api_response = api_response
    picasa_photo
  end

  def self.picasa_request_with_refresh(picasa_identity)
    begin
      yield
    rescue RestClient::Unauthorized => e
      picasa_identity.refresh_access_token!
      yield
    end
  end

end
