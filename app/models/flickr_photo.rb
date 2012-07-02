class FlickrPhoto < Photo
  
  Photo.descendent_classes ||= []
  Photo.descendent_classes << self
  
  validates_presence_of :native_photo_id
    
  def validate
    # Check to make sure the user owns the flickr photo
    if self.user && self.api_response
      if self.api_response.is_a?(Net::Flickr::Photo)
        fp_flickr_user_id = self.api_response.owner
      else
        fp_flickr_user_id = self.api_response.owner.nsid
      end
      
      if user.flickr_identity.blank? || fp_flickr_user_id != user.flickr_identity.flickr_user_id
        errors.add(:user, "must own the photo on Flickr.")
      end
    end
  end
  
  def self.get_api_response(native_photo_id, options = {})
    flickr = Net::Flickr.authorize(FLICKR_API_KEY, FLICKR_SHARED_SECRET)
    if options[:user] && options[:user].flickr_identity
      flickr.auth.token = options[:user].flickr_identity.token
    end
    flickr.photos.get_info(native_photo_id)
  rescue Net::Flickr::APIError => e
    if options.blank?
      Rails.logger.error "[ERROR #{Time.now}] Net::Flickr had an auth " + 
        "token when it shouldn't: #{flickr.auth.inspect}"
    end
    raise e
  end
  
  def self.new_from_api_response(api_response, options = {})
    logger.debug "[DEBUG] api_response.class: #{api_response.class}"
    if api_response.is_a? Net::Flickr::Photo
      new_from_net_flickr(api_response, options)
    else
      new_from_flickraw(api_response, options)
    end
  end
  
  def self.new_from_net_flickr(fp, options = {})
    options.update(
      :native_photo_id => fp.id,
      :square_url => fp.source_url(:square),
      :thumb_url => fp.source_url(:thumb),
      :small_url => fp.source_url(:small),
      :medium_url => fp.source_url(:medium),
      :large_url => fp.source_url(:large),
      :original_url => fp.source_url(:original),
      :native_page_url => fp.page_url,
      :native_username => (fp.photo_xml.at('owner')[:username] rescue nil),
      :native_realname => (fp.photo_xml.at('owner')[:realname] rescue nil),
      :license => fp.photo_xml['license']
    )
    flickr_photo = FlickrPhoto.new(options)
    flickr_photo.api_response = fp
    flickr_photo
  end
  
  def self.new_from_flickraw(fp, options = {})
    if fp.respond_to?(:urls)
      urls = fp.urls.index_by{|u| u.type}
      photopage_url = urls['photopage']._content rescue nil
    else
      photopage_url = "http://flickr.com/photos/#{fp.owner}/#{fp.id}"
    end
    options[:native_photo_id] = fp.id
    options[:native_page_url] = photopage_url
    options[:native_username] = fp.owner.username if fp.owner.respond_to?(:username)
    options[:native_username] ||= fp.owner
    options[:native_realname] = fp.owner.realname if fp.owner.respond_to?(:realname)
    options[:native_realname] ||= fp.ownername
    options[:license] ||= fp.license if fp.respond_to?(:license)
    
    # Set sizes
    if fp.respond_to?(:url_sq)
      options[:square_url]   ||= fp.to_hash["url_sq"]
      options[:thumb_url]    ||= fp.to_hash["url_t"]
      options[:small_url]    ||= fp.to_hash["url_s"]
      options[:medium_url]   ||= fp.to_hash["url_m"]
      options[:large_url]    ||= fp.to_hash["url_l"]
      options[:original_url] ||= fp.to_hash["url_o"]
    end
    
    if options[:square_url].blank? && options.delete(:skip_sizes)
      options[:square_url]   ||= "http://farm#{fp.farm}.staticflickr.com/#{fp.server}/#{fp.id}_#{fp.secret}_s.jpg"
      options[:thumb_url]    ||= "http://farm#{fp.farm}.staticflickr.com/#{fp.server}/#{fp.id}_#{fp.secret}_t.jpg"
      options[:small_url]    ||= "http://farm#{fp.farm}.staticflickr.com/#{fp.server}/#{fp.id}_#{fp.secret}_m.jpg"
    elsif options[:square_url].blank?
      unless sizes = options.delete(:sizes)
        if options[:user] && options[:user].flickr_identity
          sizes = flickr.photos.getSizes(:photo_id => fp.id, :auth_token => options[:user].flickr_identity.token)
        else
          sizes = flickr.photos.getSizes(:photo_id => fp.id)
        end
      end
      sizes = sizes.index_by{|s| s.label}
      options[:square_url]   ||= sizes['Square'].source rescue nil
      options[:thumb_url]    ||= sizes['Thumbnail'].source rescue nil
      options[:small_url]    ||= sizes['Small'].source rescue nil
      options[:medium_url]   ||= sizes['Medium'].source rescue nil
      options[:large_url]    ||= sizes['Large'].source rescue nil
      options[:original_url] ||= sizes['Original'].source rescue nil
    end
    
    flickr_photo = new(options)
    flickr_photo.api_response = fp
    flickr_photo
  end
  
  #
  # Sync photo properties with Flickr original.  Right now, that just means
  # the URLs.
  #
  def sync
    fp = self.api_response || FlickrPhoto.get_api_response(self.native_photo_id, :user => self.user)
    old_urls = [self.square_url, self.thumb_url, self.small_url, 
                self.medium_url, self.large_url, self.original_url]
    new_urls = [fp.source_url(:square), fp.source_url(:thumb), 
                fp.source_url(:small), fp.source_url(:medium), 
                fp.source_url(:large), fp.source_url(:original)]
    if old_urls != new_urls
      self.square_url    = fp.source_url(:square)
      self.thumb_url     = fp.source_url(:thumb)
      self.small_url     = fp.source_url(:small)
      self.medium_url    = fp.source_url(:medium)
      self.large_url     = fp.source_url(:large)
      self.original_url  = fp.source_url(:original)
      self.save
    end
  end
  
  def to_observation  
    # Get the Flickr data
    fp = self.api_response || FlickrPhoto.get_api_response(self.native_photo_id, :user => self.user)
    unless fp.is_a?(Net::Flickr::Photo)
      fp = FlickrPhoto.get_api_response(self.native_photo_id, :user => self.user)
      self.api_response = fp
    end
    
    # Setup the observation
    observation = Observation.new
    observation.user = self.user if self.user
    observation.photos << self
    observation.description = fp.description
    observation.observed_on_string = fp.taken.to_s(:long)
    observation.munge_observed_on_with_chronic
    observation.time_zone = observation.user.time_zone if observation.user
    
    # Get the geo fields
    begin
      observation.place_guess = %w"locality region country".map do |tag|
        fp.geo.get_location.at(tag).inner_text rescue nil
      end.compact.join(', ').strip
      observation.latitude = fp.geo.latitude
      observation.longitude = fp.geo.longitude
    rescue Net::Flickr::APIError
    end
    
    # Try to get a taxon
    observation.taxon = to_taxon
    if t = observation.taxon
      observation.species_guess = t.common_name.try(:name) || t.name
    end

    observation
  end
  
  # Try to extract known taxa from the tags of a flickr photo
  def to_taxa(options = {})
    self.api_response ||= FlickrPhoto.get_api_response(self.native_photo_id, :user => options[:user] || self.user)
    taxa = if api_response.tags.blank?
      []
    else
      # First try to find taxa matching taxonomic machine tags, then default 
      # to all tags
      tags = api_response.tags.values.map(&:raw)
      machine_tags = tags.select{|t| t =~ /taxonomy\:/}
      taxa = Taxon.tags_to_taxa(machine_tags) unless machine_tags.blank?
      taxa ||= Taxon.tags_to_taxa(tags, options)
      taxa
    end
    taxa.compact
  end
end
