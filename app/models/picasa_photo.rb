#encoding: utf-8
class PicasaPhoto < Photo
  validates_presence_of :native_photo_id
  validate :user_owns_photo
  validate :licensed_if_no_user
  
  def user_owns_photo
    if self.user
      unless self.user.picasa_identity && native_username == self.user.picasa_identity.provider_uid
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
    observation.observation_photos.build(:photo => self, :observation => observation)
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
      begin
        places = Place.elastic_paginate(
          per_page: 5,
          sort: {
            _geo_distance: {
              location: [ observation.longitude.to_f, observation.latitude.to_f ],
              unit: "km",
              order: "asc" } } )
        places = places.select {|p| p.contains_lat_lng?(observation.latitude, observation.longitude)}
        places = places.sort_by{|p| p.bbox_area || 0}
        if place = places.first
          observation.place_guess = place.display_name
        end
      rescue Riddle::ConnectionError, Riddle::ResponseError
      end
    end
    
    # Try to get a taxon
    observation.taxon = to_taxon
    if t = observation.taxon
      observation.species_guess = t.common_name.try(:name) || t.name
    end

    observation
  end
  
  def to_taxa(options = {})
    self.api_response ||= PicasaPhoto.get_api_response(self.native_photo_id, :user => self.user)
    return nil if api_response.keywords.blank?
    return nil unless api_response.keywords.is_a?(String)
    Taxon.tags_to_taxa(api_response.keywords.split(',').map(&:strip), options)
  end

  def repair
    unless r = PicasaPhoto.get_api_response(native_photo_id, :user => user)
      return [self, {
        :picasa_account_not_linked => I18n.t(:picasa_account_not_linked, :user => user.try(:login), :site_name => SITE_NAME_SHORT)
      }]
    end
    self.square_url      = r.url('72c')
    self.thumb_url       = r.url('110')
    self.small_url       = r.url('220')
    self.medium_url      = r.url('512')
    self.large_url       = r.url('1024')
    self.original_url    = r.url
    self.native_page_url = r.link('alternate').href
    save
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
      picasa = Picasa.new(picasa_identity.token)
      PicasaPhoto.picasa_request_with_refresh(picasa_identity) do
        picasa.get_url(native_photo_id, :kind => "photo,user", :thumbsize => RubyPicasa::Photo::VALID.join(','))
      end
    else
      nil
    end
  end
  
  # Create a new Photo object from an API response.
  def self.new_from_api_response(api_response, options = {})
    options[:thumb_sizes] ||= ['square','thumb','small','medium','large']
    thumb_sizes = options.delete(:thumb_sizes)
    t0 = Time.now
    if api_response.author
      native_username = api_response.author.user
      native_realname = api_response.author.nickname
    else
      native_username = api_response.user
      native_realname = api_response.nickname
    end
    license = case api_response.license.try(:url)
    when /by\//       then Photo.license_number_for_code(Observation::CC_BY)
    when /by-nc\//    then Photo.license_number_for_code(Observation::CC_BY_NC)
    when /by-sa\//    then Photo.license_number_for_code(Observation::CC_BY_SA)
    when /by-nd\//    then Photo.license_number_for_code(Observation::CC_BY_ND)
    when /by-nc-sa\// then Photo.license_number_for_code(Observation::CC_BY_NC_SA)
    when /by-nc-nd\// then Photo.license_number_for_code(Observation::CC_BY_NC_ND)
    end
    options.update(
      :user            => options[:user],
      :native_photo_id => api_response.link('self').href,
      :square_url      => (api_response.url('72c') if thumb_sizes.include?('square')),
      :thumb_url       => (api_response.url('110') if thumb_sizes.include?('thumb')),
      :small_url       => (api_response.url('220') if thumb_sizes.include?('small')),
      :medium_url      => (api_response.url('512') if thumb_sizes.include?('medium')),
      :large_url       => (api_response.url('1024') if thumb_sizes.include?('large')),
      :original_url    => api_response.url,
      :native_page_url => api_response.link('alternate').href,
      :native_username => native_username,
      :native_realname => native_realname,
      :license         => license
    )
    picasa_photo = PicasaPhoto.new(options)
    if !picasa_photo.native_username && matches = picasa_photo.native_photo_id.match(/user\/(.+?)\//)
      picasa_photo.native_username = matches[1]
    end
    picasa_photo.api_response = api_response
    picasa_photo
  end

  def self.get_photos_from_album(user, picasa_album_id, options={})
    options[:picasa_user_id] ||= nil
    options[:max_results] ||= 10
    options[:start_index] ||= 1
    return [] unless user.picasa_identity
    picasa = user.picasa_client
    # to access a friend's album, you need the full url rather than just album id. grrr.
    picasa_album_url = if options[:picasa_user_id]  
      "https://picasaweb.google.com/data/feed/api/user/#{options[:picasa_user_id]}/albumid/#{picasa_album_id}"
    end
    album_data = PicasaPhoto.picasa_request_with_refresh(user.picasa_identity) do
      picasa.album((picasa_album_url || picasa_album_id.to_s), 
        :max_results => options[:max_results], 
        :start_index => options[:start_index],
        :thumbsize => RubyPicasa::Photo::VALID.join(','))  # this also fetches photo data
    end
    photos = if album_data
      album_data.photos.map do |pp|
        PicasaPhoto.new_from_api_response(pp, :thumb_sizes=>['thumb']) 
      end
    else
      []
    end
  end

  # add a comment to the given picasa photo
  # note: picasa_photo_url looks like this:
  # https://picasaweb.google.com/data/entry/api/user/userID/albumid/albumID/photoid/photoID #?kind=comment
  # this is what picasa gives us as the native photo id
  def self.add_comment(user, picasa_photo_url, comment_text)
    return nil if user.picasa_identity.nil?
    # the ruby_picasa gem doesn't do post requests, so we're using the gdata gem instead
    picasa = GData::Client::Photos.new
    picasa.authsub_token = user.picasa_identity.token
    # the url for posting a comment is the same as the url that identifies the pic, *except* that it's /feed/ instead of /entry/. wtf.
    picasa_photo_url.sub!('entry','feed') 
    # gdata barfs unless you escape ampersands in urls
    comment_text.gsub!('&', '&amp;') 
    post_data = <<-EOF
    <entry xmlns='http://www.w3.org/2005/Atom'>
      <content>#{comment_text}</content>
      <category scheme="http://schemas.google.com/g/2005#kind" term="http://schemas.google.com/photos/2007#comment"/>
    </entry>
    EOF
    PicasaPhoto.picasa_request_with_refresh(user.picasa_identity) do
      picasa.post(picasa_photo_url, post_data)
    end
  end

  def self.picasa_request_with_refresh(picasa_identity)
    begin
      yield
    rescue RubyPicasa::PicasaError => e
      raise e unless e.message =~ /authentication/
      picasa_identity.refresh_access_token!
      yield
    end
  end

end
