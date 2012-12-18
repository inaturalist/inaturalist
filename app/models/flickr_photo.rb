#encoding: utf-8
class FlickrPhoto < Photo
  
  Photo.descendent_classes ||= []
  Photo.descendent_classes << self
  
  validates_presence_of :native_photo_id
  validate :user_owns_photo

  def user_owns_photo
    if user
      @api_response ||= FlickrPhoto.get_api_response(native_photo_id, :user => user)
      fp_flickr_user_id = @api_response.owner.nsid
      
      if user.flickr_identity.blank? && self.observations.by(user).exists?
        # assume the user used to have a FlickrIdentity and used it to import this photo, 
        # but has since removed the FlickrIdentity
      elsif user.flickr_identity.blank? || fp_flickr_user_id != user.flickr_identity.flickr_user_id
        errors.add(:user, "must own the photo on Flickr.")
      end
    end
  end
  
  def self.flickraw_for_user(user)
    return flickr unless (user && user.flickr_identity)
    f = FlickRaw::Flickr.new
    f.access_token = user.flickr_identity.token
    f.access_secret = user.flickr_identity.secret
    f
  end
  
  def self.get_api_response(native_photo_id, options = {})
    f = options[:user] ? flickraw_for_user(options[:user]) : flickr
    f.photos.getInfo(:photo_id => native_photo_id)
  rescue FlickRaw::FailedResponse => e
    raise e unless e.message =~ /Invalid auth token/
    flickr.photos.getInfo(:photo_id => native_photo_id)
  end
  
  def self.new_from_api_response(api_response, options = {})
    new_from_flickraw(api_response, options)
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
        f = FlickrPhoto.flickraw_for_user(options[:user])
        sizes = f.photos.getSizes(:photo_id => fp.id)
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
    f = FlickrPhoto.flickraw_for_user(user)
    sizes = f.photos.getSizes(:photo_id => native_photo_id)
    sizes = sizes.index_by{|s| s.label}
    self.square_url   = sizes['Square'].source rescue nil
    self.thumb_url    = sizes['Thumbnail'].source rescue nil
    self.small_url    = sizes['Small'].source rescue nil
    self.medium_url   = sizes['Medium'].source rescue nil
    self.large_url    = sizes['Large'].source rescue nil
    self.original_url = sizes['Original'].source rescue nil
    save
  end
  
  def to_observation  
    # Get the Flickr data
    self.api_response ||= FlickrPhoto.get_api_response(self.native_photo_id, :user => self.user)
    fp = self.api_response
    
    # Setup the observation
    observation = Observation.new
    observation.user = self.user if self.user
    observation.observation_photos.build(:photo => self)
    observation.description = fp.description
    observation.observed_on_string = fp.dates.taken
    observation.munge_observed_on_with_chronic
    observation.time_zone = observation.user.time_zone if observation.user
    
    # Get the geo fields
    if fp.respond_to?(:location)
      observation.place_guess = %w"locality region country".map do |level|
        fp.location[level].try(:_content)
      end.compact.join(', ').strip
      observation.latitude  = fp.location.latitude
      observation.longitude = fp.location.longitude
      observation.map_scale = fp.location.accuracy
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
      tags = api_response.tags.map{|t| t.raw}
      machine_tags = tags.select{|t| t =~ /taxonomy\:/}
      taxa = Taxon.tags_to_taxa(machine_tags, options) unless machine_tags.blank?
      taxa ||= Taxon.tags_to_taxa(tags, options)
      taxa
    end
    taxa.compact
  end

  def repair
    errors = {}
    f = FlickrPhoto.flickraw_for_user(user)
    begin
      sizes = begin
        f.photos.getSizes(:photo_id => native_photo_id)
      rescue FlickRaw::FailedResponse => e
        raise e unless e.message =~ /Invalid auth token/
        flickr.photos.getSizes(:photo_id => native_photo_id)
      end
      self.square_url    = sizes.detect{|s| s.label == 'Square'}.try(:source)
      self.thumb_url     = sizes.detect{|s| s.label == 'Thumbnail'}.try(:source)
      self.small_url     = sizes.detect{|s| s.label == 'Small'}.try(:source)
      self.medium_url    = sizes.detect{|s| s.label == 'Medium'}.try(:source)
      self.large_url     = sizes.detect{|s| s.label == 'Large'}.try(:source)
      self.original_url  = sizes.detect{|s| s.label == 'Original'}.try(:source)
      if changed?
        puts "[DEBUG] updated #{self}, changed: #{changed.join(', ')}"
        save
      end
    rescue FlickRaw::FailedResponse => e
      if e.message =~ /Photo not found/
        errors[:photo_missing_from_flickr] = "photo not found #{self}"
      else
        raise e
      end
    rescue NoMethodError => e
      raise e unless e.message =~ /token/
      errors[:flickr_authorization_missing] = "missing FlickrIdentity for #{user}"
    end

    if errors[:photo_missing_from_flickr] || (errors[:flickr_authorization_missing] && orphaned?)
      destroy
    end
    [self, errors]
  end

  def self.add_comment(user, flickr_photo_id, comment_text)
    return nil if user.flickr_identity.nil?
    flickr = FlickrPhoto.flickraw_for_user(user)
    flickr.photos.comments.addComment(
      :user_id => user.flickr_identity.flickr_user_id, 
      :auth_token => user.flickr_identity.token,
      :photo_id => flickr_photo_id, 
      :comment_text => comment_text
    )
  end

  def self.repair(find_options = {})
    puts "[INFO #{Time.now}] starting FlickrPhoto.repair, options: #{find_options.inspect}"
    find_options[:include] ||= [{:user => :flickr_identity}, :taxon_photos, :observation_photos]
    find_options[:batch_size] ||= 100
    find_options[:sleep] ||= 10
    flickr = FlickRaw::Flickr.new
    updated = 0
    destroyed = 0
    invalids = 0
    skipped = 0
    start_time = Time.now
    FlickrPhoto.script_do_in_batches(find_options) do |p|
      r = Net::HTTP.get_response(URI.parse(p.medium_url))
      unless r.code_type == Net::HTTPBadRequest
        skipped += 1
        next
      end
      repaired, errors = p.repair
      if errors.blank?
        updated += 1
      else
        puts "[DEBUG] #{errors.values.to_sentence}"
        if repaired.frozen?
          destroyed += 1 
          puts "[DEBUG] destroyed #{repaired}"
        end
        if errors[:flickr_authorization_missing]
          invalids += 1
          puts "[DEBUG] authorization missing #{repaired}"
        end
      end
    end
    puts "[INFO #{Time.now}] finished FlickrPhoto.repair, #{updated} updated, #{destroyed} destroyed, #{invalids} invalid, #{skipped} skipped, #{Time.now - start_time}s"
  end

end
