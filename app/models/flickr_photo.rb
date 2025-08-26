# frozen_string_literal: true

class FlickrPhoto < Photo
  acts_as_flaggable

  validates_presence_of :native_photo_id
  validate :user_owns_photo
  validate :licensed_if_no_user

  FLICKR_LICENSES = [{
    id: 0,
    name: "All Rights Reserved",
    url: "https://www.flickrhelp.com/hc/en-us/articles/10710266545556-Using-Flickr-images-shared-by-other-members"
  }, {
    id: 1,
    name: "CC BY-NC-SA 2.0",
    url: "https://creativecommons.org/licenses/by-nc-sa/2.0/"
  }, {
    id: 2,
    name: "CC BY-NC 2.0",
    url: "https://creativecommons.org/licenses/by-nc/2.0/"
  }, {
    id: 3,
    name: "CC BY-NC-ND 2.0",
    url: "https://creativecommons.org/licenses/by-nc-nd/2.0/"
  }, {
    id: 4,
    name: "CC BY 2.0",
    url: "https://creativecommons.org/licenses/by/2.0/"
  }, {
    id: 5,
    name: "CC BY-SA 2.0",
    url: "https://creativecommons.org/licenses/by-sa/2.0/"
  }, {
    id: 6,
    name: "CC BY-ND 2.0",
    url: "https://creativecommons.org/licenses/by-nd/2.0/"
  }, {
    id: 7,
    name: "No known copyright restrictions",
    url: "https://www.flickr.com/commons/usage/"
  }, {
    id: 8,
    name: "United States Government Work",
    url: "https://www.usa.gov/government-copyright"
  }, {
    id: 9,
    name: "Public Domain Dedication (CC0)",
    url: "https://creativecommons.org/publicdomain/zero/1.0/"
  }, {
    id: 10,
    name: "Public Domain Mark",
    url: "https://creativecommons.org/publicdomain/mark/1.0/"
  }, {
    id: 11,
    name: "CC BY 4.0",
    url: "https://creativecommons.org/licenses/by/4.0/"
  }, {
    id: 12,
    name: "CC BY-SA 4.0",
    url: "https://creativecommons.org/licenses/by-sa/4.0/"
  }, {
    id: 13,
    name: "CC BY-ND 4.0",
    url: "https://creativecommons.org/licenses/by-nd/4.0/"
  }, {
    id: 14,
    name: "CC BY-NC 4.0",
    url: "https://creativecommons.org/licenses/by-nc/4.0/"
  }, {
    id: 15,
    name: "CC BY-NC-SA 4.0",
    url: "https://creativecommons.org/licenses/by-nc-sa/4.0/"
  }, {
    id: 16,
    name: "CC BY-NC-ND 4.0",
    url: "https://creativecommons.org/licenses/by-nc-nd/4.0/"
  }].freeze

  def user_owns_photo
    return unless user

    @api_response ||= FlickrPhoto.get_api_response( native_photo_id, user: user )
    fp_flickr_user_id = @api_response.owner.nsid

    if user.flickr_identity.blank? && observations.by( user ).exists?
      # assume the user used to have a FlickrIdentity and used it to import this photo,
      # but has since removed the FlickrIdentity
    elsif user.flickr_identity.blank? || fp_flickr_user_id != user.flickr_identity.flickr_user_id
      errors.add( :user, "must own the photo on Flickr." )
    end
  end

  def self.flickr_for_user( user )
    f = Flickr.new( Flickr.api_key, Flickr.shared_secret )
    return f unless user&.flickr_identity

    f.access_token = user.flickr_identity.token
    f.access_secret = user.flickr_identity.secret
    f
  end

  def self.get_api_response( native_photo_id, options = {} )
    f = if options[:user]
      flickr_for_user( options[:user] )
    else
      Flickr.new( Flickr.api_key, Flickr.shared_secret )
    end
    user_id = options[:user].id if options[:user].is_a?( User )
    f.photos.getInfo( photo_id: native_photo_id )
    r = Rails.cache.fetch( "flickr_photos_getInfo_#{native_photo_id}_#{user_id}", expires_in: 5.minutes ) do
      f.photos.getInfo( photo_id: native_photo_id )
    end
    if r.blank?
      r = f.photos.getInfo( photo_id: native_photo_id )
    end
    r
  rescue Flickr::FailedResponse => e
    if e.message =~ /Invalid auth token/
      flickr.photos.getInfo( photo_id: native_photo_id )
    elsif e.message =~ /invalid ID/
      nil
    else
      raise e
    end
  end

  def self.new_from_api_response( api_response, options = {} )
    new_from_flickr( api_response, options )
  end

  def self.new_from_flickr( flickr_photo, options = {} )
    if flickr_photo.respond_to?( :urls )
      urls = flickr_photo.urls.index_by( &:type )
      photopage_url = urls["photopage"]&._content
    else
      photopage_url = "https://flickr.com/photos/#{flickr_photo.owner}/#{flickr_photo.id}"
    end
    options[:native_photo_id] = flickr_photo.id
    options[:native_page_url] = photopage_url
    options[:native_username] = flickr_photo.owner.username if flickr_photo.owner.respond_to?( :username )
    options[:native_username] ||= flickr_photo.owner
    options[:native_realname] = flickr_photo.owner.realname if flickr_photo.owner.respond_to?( :realname )
    options[:native_realname] ||= flickr_photo.ownername
    if flickr_photo.respond_to?( :license ) && !options[:license] && (
      flickr_photo.license.is_a?( Integer ) || flickr_photo.license.to_i.to_s == flickr_photo.license
    )
      if flickr_photo.license.to_i <= 9
        options[:license] = flickr_photo.license.to_i
      elsif ( flickr_license = FLICKR_LICENSES.detect {| fl | fl[:id] == flickr_photo.license.to_i } )
        options[:license] = Shared::LicenseModule.license_number_for_url( flickr_license[:url] )
      end
    end

    # Set sizes
    # flickr_photo could be an OpenStruct or a Flickr::Response
    h = ( flickr_photo.to_hash || flickr_photo.to_h ).symbolize_keys
    if h[:url_sq]
      options[:remote_square_url]   ||= h[:url_sq]
      options[:remote_thumb_url]    ||= h[:url_t]
      options[:remote_small_url]    ||= h[:url_s]
      options[:remote_medium_url]   ||= h[:url_m]
      options[:remote_large_url]    ||= h[:url_l]
      options[:remote_original_url] ||= h[:url_o]
    end

    if options[:remote_square_url].blank? && options.delete( :skip_sizes )
      options[:remote_square_url]   ||= "http://farm#{flickr_photo.farm}.staticflickr.com/#{flickr_photo.server}/#{flickr_photo.id}_#{flickr_photo.secret}_s.jpg"
      options[:remote_thumb_url]    ||= "http://farm#{flickr_photo.farm}.staticflickr.com/#{flickr_photo.server}/#{flickr_photo.id}_#{flickr_photo.secret}_t.jpg"
      options[:remote_small_url]    ||= "http://farm#{flickr_photo.farm}.staticflickr.com/#{flickr_photo.server}/#{flickr_photo.id}_#{flickr_photo.secret}_m.jpg"
    elsif options[:remote_square_url].blank?
      unless ( sizes = options.delete( :sizes ) )
        f = FlickrPhoto.flickr_for_user( options[:user] )
        sizes = FlickrCache.fetch( f, "photos", "getSizes", photo_id: flickr_photo.id )
      end
      sizes = sizes.blank? ? {} : sizes.index_by( &:label ) rescue {}
      options[:remote_square_url]   ||= sizes["Square"]&.source
      options[:remote_thumb_url]    ||= sizes["Thumbnail"]&.source
      options[:remote_small_url]    ||= sizes["Small"]&.source
      options[:remote_medium_url]   ||= sizes["Medium"]&.source
      options[:remote_large_url]    ||= sizes["Large"]&.source
      options[:remote_original_url] ||= sizes["Original"]&.source
    end

    photo = new( options )
    photo.api_response = flickr_photo
    photo
  end

  #
  # Sync photo properties with Flickr original.  Right now, that just means
  # the URLs.
  #
  def sync
    f = FlickrPhoto.flickr_for_user( user )
    sizes = begin
      f.photos.getSizes( photo_id: native_photo_id )
    rescue Flickr::FailedResponse => e
      raise e unless e =~ /Photo not found/

      nil
    end
    return if sizes.blank?

    sizes = sizes.index_by( &:label )
    self.square_url   = sizes["Square"]&.source
    self.thumb_url    = sizes["Thumbnail"]&.source
    self.small_url    = sizes["Small"]&.source
    self.medium_url   = sizes["Medium"]&.source
    self.large_url    = sizes["Large"]&.source
    self.original_url = sizes["Original"]&.source
    save
  end

  def to_observation
    # Get the Flickr data
    self.api_response ||= FlickrPhoto.get_api_response( native_photo_id, user: user )
    fp = self.api_response

    # Setup the observation
    observation = Observation.new
    observation.user = user if user
    observation.observation_photos.build( photo: self )
    observation.description = fp.description
    observation.observed_on_string = fp.dates.taken
    observation.munge_observed_on_with_chronic
    observation.time_zone = observation.user.time_zone if observation.user

    # Get the geo fields
    if fp.respond_to?( :location )
      observation.place_guess = %w(locality region country).map do | level |
        fp.location[level].try( :_content ) || fp.location[level].to_s
      end.compact.join( ", " ).strip
      observation.latitude  = fp.location.latitude
      observation.longitude = fp.location.longitude
      observation.map_scale = fp.location.accuracy
    end

    # Try to get a taxon
    observation.taxon = to_taxon
    if ( t = observation.taxon )
      t.current_user = observation.user
      observation.species_guess = t.common_name( user: observation.user ).try( :name ) || t.name
    end

    observation.tag_list = to_tags

    observation
  end

  def to_tags( options = {} )
    self.api_response ||= FlickrPhoto.get_api_response( native_photo_id,
      user: options[:user] || user )
    [( api_response.tags || [] ).map( &:raw ), api_response.title].flatten.compact.uniq
  end

  # Try to extract known taxa from the tags of a flickr photo
  def to_taxa( options = {} )
    tags = to_tags( options )
    taxa = if tags.blank?
      []
    else
      # First try to find taxa matching taxonomic machine tags, then default
      # to all tags
      tags = [tags, api_response.title].flatten.compact.uniq
      machine_tags = tags.grep( /taxonomy:/ )
      taxa = Taxon.tags_to_taxa( machine_tags, options ) unless machine_tags.blank?
      taxa ||= Taxon.tags_to_taxa( tags, options )
      taxa
    end
    taxa.compact
  end

  def repair( options = {} )
    errors = {}
    f = FlickrPhoto.flickr_for_user( user )
    begin
      sizes = begin
        f.photos.getSizes( photo_id: native_photo_id )
      rescue Flickr::FailedResponse => e
        raise e unless e.message =~ /Invalid auth token/

        flickr.photos.getSizes( photo_id: native_photo_id )
      end
      self.square_url    = sizes.detect {| s | s.label == "Square" }.try( :source )
      self.thumb_url     = sizes.detect {| s | s.label == "Thumbnail" }.try( :source )
      self.small_url     = sizes.detect {| s | s.label == "Small" }.try( :source )
      self.medium_url    = sizes.detect {| s | s.label == "Medium" }.try( :source )
      self.large_url     = sizes.detect {| s | s.label == "Large" }.try( :source )
      self.original_url  = sizes.detect {| s | s.label == "Original" }.try( :source )
      if changed? && !options[:no_save]
        save
      end
    rescue Flickr::FailedResponse => e
      if e.message =~ /Photo not found/
        errors[:photo_missing_from_flickr] = "photo not found #{self}"
      else
        errors[:flickr_error] = "Unknown problem on Flickr's end"
      end
    rescue NoMethodError => e
      raise e unless e.message =~ /token/

      errors[:flickr_authorization_missing] = "missing FlickrIdentity for #{user}"
    rescue Errno::ECONNRESET
      errors[:flickr_refusing_connection] = "Flickr is refusing the connection for some reason"

    # catch-all
    rescue EOFError
      errors[:flickr_error] = "Unknown problem on Flickr's end"
    end

    if (
      errors[:photo_missing_from_flickr] ||
      ( errors[:flickr_authorization_missing] && orphaned? )
    ) && !options[:no_save]
      destroy
    end
    [self, errors]
  end

  def self.add_comment( user, flickr_photo_id, comment_text )
    return nil if user.flickr_identity.nil?

    flickr = FlickrPhoto.flickr_for_user( user )
    flickr.photos.comments.addComment(
      user_id: user.flickr_identity.flickr_user_id,
      auth_token: user.flickr_identity.token,
      photo_id: flickr_photo_id,
      comment_text: comment_text
    )
  end

  def self.repair( find_options = {} )
    puts "[INFO #{Time.now}] starting FlickrPhoto.repair, options: #{find_options.inspect}"
    find_options[:include] ||= [{ user: :flickr_identity }, :taxon_photos, :observation_photos]
    find_options[:batch_size] ||= 100
    find_options[:sleep] ||= 10
    updated = 0
    destroyed = 0
    invalids = 0
    skipped = 0
    start_time = Time.now
    counter = 0
    FlickrPhoto.includes( find_options[:include] ).where( find_options[:where] ).
      find_each( batch_size: find_options[:batch_size] ) do | p |
      counter += 1
      sleep( find_options[:sleep] ) if ( counter % find_options[:batch_size] ).zero?
      r = begin
        uri = URI.parse( p.square_url )
        Net::HTTP.new( uri.host ).request_head( uri.path )
      rescue URI::InvalidURIError
        puts "[ERROR] Failed to retrieve #{p.square_url}, skipping..."
        skipped += 1
        next
      rescue Timeout::Error, Errno::ECONNREFUSED => e
        puts "[ERROR] #{e.message} (#{e.class.name}), skipping..."
        skipped += 1
        next
      end
      unless r.is_a?( Net::HTTPBadRequest ) || r.is_a?( Net::HTTPRedirection )
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
        if errors[:flickr_authorization_missing]
          invalids += 1
          puts "[ERROR] authorization missing #{repaired}"
        end
      end
    end
    puts "[INFO #{Time.now}] finished FlickrPhoto.repair, #{updated} updated, " \
      "#{destroyed} destroyed, #{invalids} invalid, #{skipped} skipped, #{Time.now - start_time}s"
  end
end
