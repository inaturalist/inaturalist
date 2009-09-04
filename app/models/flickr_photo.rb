class FlickrPhoto < ActiveRecord::Base
  belongs_to :user
  has_and_belongs_to_many :observations
  has_and_belongs_to_many :taxa
  validates_presence_of :flickr_native_photo_id
  
  attr_accessor :flickr_response
  
  def validate
    if self.user.nil? and self.flickr_license == 0
      errors.add(
        :flickr_license, 
        "must be a Creative Commons license if the photo wasn't added by " +
        "an iNaturalist user using their linked Flickr account.")
    end
    
    # Check to make sure the user owns the flickr photo
    if self.user && self.flickr_response
      if self.flickr_response.is_a?(Net::Flickr::Photo)
        fp_flickr_user_id = self.flickr_response.owner
      else
        fp_flickr_user_id = self.flickr_response.owner.nsid
      end
      
      unless fp_flickr_user_id == self.user.flickr_identity.flickr_user_id
        errors.add(:user, "must own the photo on Flickr.")
      end
    end
  end
  
  def self.new_from_net_flickr(fp, options = {})
    options.update(
      :flickr_native_photo_id => fp.id,
      :square_url => fp.source_url(:square),
      :thumb_url => fp.source_url(:thumb),
      :small_url => fp.source_url(:small),
      :medium_url => fp.source_url(:medium),
      :large_url => fp.source_url(:large),
      :original_url => fp.source_url(:original),
      :flickr_page_url => fp.page_url,
      :flickr_username => (fp.photo_xml.at('owner')[:username] rescue nil),
      :flickr_realname => (fp.photo_xml.at('owner')[:realname] rescue nil),
      :flickr_license => fp.photo_xml['license']
    )
    flickr_photo = FlickrPhoto.new(options)
    flickr_photo.flickr_response = fp
    flickr_photo
  end
  
  def self.new_from_flickraw(fp, options = {})
    FlickRaw.api_key = FLICKR_API_KEY
    FlickRaw.shared_secret = FLICKR_SHARED_SECRET
    urls = fp.urls.index_by(&:type)
    photopage_url = urls['photopage']._content rescue nil
    options.update(
      :flickr_native_photo_id => fp.id,
      :flickr_page_url        => photopage_url,
      :flickr_username        => fp.owner.username,
      :flickr_realname        => fp.owner.realname,
      :flickr_license         => fp.license
    )
    
    # Set sizes
    unless sizes = options.delete(:sizes)
      if options[:user] && options[:user].flickr_identity
        sizes = flickr.photos.getSizes(:photo_id => fp.id, 
          :auth_token => options[:user].flickr_identity.token)
      else
        sizes = flickr.photos.getSizes(:photo_id => fp.id)
      end
    end
    sizes = sizes.index_by(&:label)
    options[:square_url]   ||= sizes['Square'].source rescue nil
    options[:thumb_url]    ||= sizes['Thumbnail'].source rescue nil
    options[:small_url]    ||= sizes['Small'].source rescue nil
    options[:medium_url]   ||= sizes['Medium'].source rescue nil
    options[:large_url]    ||= sizes['Large'].source rescue nil
    options[:original_url] ||= sizes['Original'].source rescue nil
    
    flickr_photo = new(options)
    flickr_photo.flickr_response = fp
    flickr_photo
  end
  
  # Return a string with attribution info about this photo
  def attribution
    case self.flickr_license
    when 0
      rights = '(c)'
    when nil
      rights = '(c)'
    when 7
      rights = '(o)'
    else
      rights = '(cc)'
    end
    
    if !self.flickr_realname.blank?
      name = self.flickr_realname
    elsif !self.flickr_username.blank?
      name = self.flickr_username
    elsif !self.observations.empty?
      name = self.observations.first.user.login
    else
      name = "anonymous Flickr user"
    end

    "#{rights} #{name}"
  end
  
  #
  # Sync photo properties with Flickr original.  Right now, that just means
  # the URLs.
  #
  def sync
    unless fp = self.flickr_response
      flickr = Net::Flickr.authorize(FLICKR_API_KEY, FLICKR_SHARED_SECRET)
      flickr.auth.token = self.user.flickr_identity.token
      fp = flickr.photos.get_info(self.flickr_native_photo_id)
    end
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
    flickr = Net::Flickr.authorize(FLICKR_API_KEY, FLICKR_SHARED_SECRET)
    if self.user && self.user.flickr_identity
      flickr.auth.token = self.user.flickr_identity.token
    end
    fp = flickr.photos.get_info(self.flickr_native_photo_id)
    
    # Setup the observation
    observation = Observation.new
    observation.user = self.user if self.user
    observation.flickr_photos << self
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
    taxa = to_taxa(:flickr => flickr, :fp => fp)
    unless taxa.empty?
      observation.taxon = taxa.find(&:species_or_lower?)
      observation.taxon ||= taxa.first
      
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
  
  # Try to extract known taxa from the tags of a flickr photo
  def to_taxa(options = {})
    flickr = options.delete(:flickr)
    fp = options.delete(:fp)
    flickr ||= Net::Flickr.authorize(FLICKR_API_KEY, FLICKR_SHARED_SECRET)
    fp ||= flickr.photos.get_info(self.flickr_native_photo_id)
    FlickrPhoto.flickr_photo_to_taxa(fp)
  end
  
  def self.flickr_photo_to_taxa(fp)
    taxon_names = fp.tags.values.map do |tag|
      if matches = tag.raw.match(/^taxonomy:\w+=(.*)/)
        TaxonName.find_by_name(matches[0])
      else
        TaxonName.find_by_name(tag.raw)
      end
    end.compact
    taxon_names.map(&:taxon).compact
  end
end
