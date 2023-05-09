#encoding: utf-8
class LocalPhoto < Photo
  include LogsDestruction
  after_create :set_urls
  after_update :change_photo_bucket_if_needed
  
  # only perform EXIF-based rotation on mobile app contributions
  image_convert_options = Proc.new {|record|
    record.rotation.blank? ? "-auto-orient" : nil
  }
  
  file_options = {
    preserve_files: true,
    styles: {
      original: { geometry: "2048x2048>", auto_orient: false, processors: [ :rotator, :metadata_filter ] },
      large:    { geometry: "1024x1024>", auto_orient: false },
      medium:   { geometry: "500x500>",   auto_orient: false },
      small:    { geometry: "240x240>",   auto_orient: false, processors: [ :deanimator ] },
      thumb:    { geometry: "100x100>",   auto_orient: false, processors: [ :deanimator ] },
      square:   { geometry: "75x75#",     auto_orient: false, processors: [ :deanimator ] }
    },
    convert_options: {
      original: image_convert_options,
      large:    image_convert_options,
      medium:   image_convert_options,
      small:    image_convert_options,
      thumb:    image_convert_options,
      square:   image_convert_options
    },
    default_url: "/attachment_defaults/:class/:style.png"
  }

  if CONFIG.usingS3

    # the s3 config is dynamic, based on the photo. We now recognizing
    # two buckets - our main S3 bucket which remains public, as well
    # as a second bucket for openly-licensed photos. The contents of both
    # are public, but we may refer to the second bucket either as the public
    # bucket, since it contains openly-licensed photos, or the ODP
    # (AWS Open Dataset Program) bucket.

    # All the S3 config parameters are as follows:
    #   s3_bucket: the unique name of the S3 bucket at AWS
    #   s3_host (optional): the full hostname for the bucket, e.g. s3_bucket.s3.amazonaws.com
    #   s3_protocol: should always be `https` unless you absolutely need to use http for some reason
    #   s3_region: S3 region that bucket lives in
    # and these which do the same as above, but for a secondary bucket for openly-licensed photos
    #   s3_public_bucket
    #   s3_public_host (optional)
    #   s3_public_region: For now we assume the region is the same, and that is recommended practice
    #   s3_public_acl: You can set this to `bucket-owner-full-control` to transfer ownership
    #     when moving photos to this bucket

    has_attached_file :file, file_options.merge(
      storage: :s3,
      s3_credentials: "#{Rails.root}/config/s3.yml",
      s3_protocol: CONFIG.s3_protocol || "https",
      s3_host_alias: Proc.new{ |a| a.instance.s3_host_alias },
      s3_region: Proc.new{ |a| a.instance.s3_region },
      s3_permissions: Proc.new{ |a| a.instance.s3_permissions },
      bucket: Proc.new{ |a| a.instance.s3_bucket },
      #
      #  NOTE: the path used to be "photos/:id/:style.:extension" as of
      #  2016-07-15, but that wasn't setting the extension based on the detected
      #  content type, just echoing what was in the file name. So if you're
      #  trying to use file.url or file.path for photos older than 2016-07-15,
      #  you'll probably want to fetch the original from original_url first
      #  before you do any work on the photo.
      #
      path: "photos/:id/:style.:content_type_extension",
      url: ":s3_alias_url",
    )
    invalidate_cloudfront_caches :file, "photos/:id/*"
  else
    has_attached_file :file, file_options.merge(
      path: ":rails_root/public/attachments/:class/:attachment/:id/:style.:content_type_extension",
      url: "/attachments/:class/:attachment/:id/:style.:content_type_extension",
    )
  end

  # we want to grab metadata from remote photos so make sure
  # to pull the metadata from the true original, i.e. before
  # post_processing which creates thumbnails
  before_post_process :extract_metadata
  after_post_process :set_urls
  # ...but part of the metadata is the size of the thumbnails
  # so grab metadata twice (extract_metadata is purely additive)
  after_post_process :extract_metadata

  after_initialize :set_license

  # LocalPhotos with subtypes are former remote photos, and subtype
  # is the former subclass. Those subclasses don't validate :user
  validates_presence_of :user, unless: :subtype
  validates_attachment_content_type :file, content_type: Photo::MIME_PATTERNS,
    :message => "must be JPG, PNG, or GIF"

  attr_accessor :rotation, :skip_delay, :skip_cloudfront_invalidation

  BRANDED_DESCRIPTIONS = [
    "OLYMPUS DIGITAL CAMERA",
    "SONY DSC",
    "MOULTRIE DIGITAL GAME CAMERA",
    "<KENOX S1050 / Samsung S1050>",
    "KODAK Digital Still Camera",
    "DIGITAL CAMERA",
    "SAMSUNG CAMERA PICTURES",
    "MINOLTA DIGITAL CAMERA"
  ]

  def self.odp_s3_bucket_enabled?
    !!( CONFIG.s3_public_host || CONFIG.s3_public_bucket )
  end

  def self.s3_host_alias( public = false )
    unless LocalPhoto.odp_s3_bucket_enabled?
      return ( CONFIG.s3_host || CONFIG.s3_bucket )
    end
    public ?
      ( CONFIG.s3_public_host || CONFIG.s3_public_bucket ) :
      ( CONFIG.s3_host || CONFIG.s3_bucket )
  end

  def self.s3_region( public = false )
    return CONFIG.s3_region unless CONFIG.s3_public_region
    public ? CONFIG.s3_public_region : CONFIG.s3_region
  end

  def self.s3_bucket( public = false )
    return CONFIG.s3_bucket unless CONFIG.s3_public_bucket
    public ? CONFIG.s3_public_bucket : CONFIG.s3_bucket
  end

  def self.s3_permissions( public = false )
    return "public-read" unless CONFIG.s3_public_bucket && CONFIG.s3_public_acl
    public ? CONFIG.s3_public_acl : "public-read"
  end

  def s3_host_alias
    LocalPhoto.s3_host_alias( self.s3_account )
  end

  def s3_region
    LocalPhoto.s3_region( self.s3_account )
  end

  def s3_bucket
    LocalPhoto.s3_bucket( self.s3_account )
  end

  def s3_permissions
    LocalPhoto.s3_permissions( self.s3_account )
  end

  def in_public_s3_bucket?
    file_prefix ? !! file_prefix.prefix.match( LocalPhoto.s3_bucket( true ) ) :
      could_be_public
  end

  def s3_account
    return @s3_account if instance_variable_defined?( :@s3_account )
    @s3_account = self.in_public_s3_bucket? ? "public" : nil
  end

  def s3_account=( account )
    @s3_account = account
  end

  def could_be_public
    return false unless Shared::LicenseModule::ODP_LICENSES.include?( self.license )
    return false if flags.any?{ |f| !f.resolved? }
    true
  end

  def self.change_photo_bucket_if_needed( p )
    return unless p = LocalPhoto.find_by_id( p ) unless p.is_a?( LocalPhoto )
    p.change_photo_bucket_if_needed
  end

  def photo_bucket_should_be_changed?
    # must have a URL
    return false unless file_prefix
    return false unless CONFIG.usingS3
    # the code must be configured to use a public bucket
    return false unless LocalPhoto.odp_s3_bucket_enabled?
    # the LocalPhoto must be in a bucket other than what its license dictates
    return false unless ( could_be_public && !in_public_s3_bucket? ) ||
      (!could_be_public && in_public_s3_bucket? )
    true
  end

  def change_photo_bucket_if_needed
    return unless photo_bucket_should_be_changed?
    LocalPhoto.move_to_appropriate_bucket( self )
  end

  # I think this may be impossible using delayed_paperclip
  # validates_attachment_presence :file
  # validates_attachment_size :file, :less_than => 5.megabytes
  
  def file=(data)
    self.file.assign(data)
    # uploaded photos need metadata immediately in order to
    # "Sync obs. w/ photo metadata"
    if data.is_a?(ActionDispatch::Http::UploadedFile)
      extract_metadata(data.path)
    end
  end

  def extract_metadata(path = nil)
    return unless file && (path || !file.queued_for_write.blank?)
    extracted_metadata = metadata.to_h.clone || {}
    begin
      if ( file_path = ( path || file.queued_for_write[:original].path ) )
        exif_data = ExifMetadata.new( path: file_path, type: file_content_type ).extract
        extracted_metadata.merge!( exif_data )
      end
    rescue EXIFR::MalformedImage, EOFError => e
      Rails.logger.error "[ERROR #{Time.now}] Failed to parse EXIF for #{self}: #{e}"
    rescue NoMethodError => e
      raise e unless e.message =~ /path.*StringIO/
      Rails.logger.error "[ERROR #{Time.now}] Failed to parse EXIF for #{self}: #{e}"
    rescue TypeError => e
      raise e unless e.message =~ /no implicit conversion of Integer into String/
      Rails.logger.error "[ERROR #{Time.now}] Failed to parse EXIF for #{self}: #{e}"
    rescue ExifMetadata::ExtractionError => e
      Rails.logger.error "[ERROR #{Time.now}] ExifMetadata failed to extract metadata: #{e}"
    end
    extracted_metadata = extracted_metadata.force_utf8
    if dimensions = extract_dimensions( :original )
      self.width = dimensions[:width]
      self.height = dimensions[:height]
    end
    self.photo_metadata ||= PhotoMetadata.new( photo: self )
    self.photo_metadata.metadata = extracted_metadata
  end

  def set_urls
    return if new_record?
    updates = { }
    updates[:file_extension_id] = FileExtension.id_for_extension( self.parse_extension )
    updates[:file_prefix_id] = FilePrefix.id_for_prefix( self.parse_url_prefix )
    Photo.where( id: id ).update_all( updates )
    true
  end

  def reset_file_from_original
    interpolated_original_url = ApplicationController.helpers.image_url( self.file.url(:original) )
    
    # If we're using local file storage and using some kind of development-ish
    # setup, it probably means we're running a single server process, which
    # means running a HEAD request while *this* request is running is going to
    # cause problems, but it also means that the original file is *probably*
    # there so we can skip this file reset business.
    return if interpolated_original_url =~ /localhost/

    # If the original file is there under the current path, no need to do anything
    return if Photo.valid_remote_photo_url?( interpolated_original_url )
    
    # If it's not, check the old path
    attachment_opts = LocalPhoto.attachment_definitions[:file]
    image_url_opts = if CONFIG.usingS3
      { base_url: "#{attachment_opts[:s3_protocol]}://#{attachment_opts[:bucket]}" }
    else
      {}
    end
    old_interpolated_original_url = ApplicationController.helpers.image_url(
      Paperclip::Interpolations.interpolate( "photos/:id/:style.:extension", self.file, "original" ),
      image_url_opts
    )
    url = if Photo.valid_remote_photo_url?( old_interpolated_original_url )
      old_interpolated_original_url
    
    # If it's not at the old path, use the cached original_url if it's not copyright infringement
    elsif original_url !~ /copyright/
      ApplicationController.helpers.image_url( original_url )

    # If this is a copyright violation AND we don't have access to an original file, we're screwed.
    else
      raise Photo::MissingPhotoError.new( "We no longer have access to the original file" )
    end

    Timeout::timeout(10) do
      self.file = URI( url )
    end
  end

  def repair(options = {})
    reset_file_from_original
    self.file.reprocess!
    [self, {}]
  end

  def attribution
    if user.blank? || [user.name, user.login].include?( native_realname )
      # If this was imported from Flickr or Wikipedia and there's either no user
      # we might attribute the photo to OR there is a user but they seem to be
      # the person who the third party says took the photo, just do normal attribution
      return super
    end

    # Otherwise, note that the user uploaded it, as opposed to specifying that
    # they took it
    uploader_name = attribution_name
    I18n.t(
      :attribution_uploaded_by_user,
      attribution: super,
      user: uploader_name,
      vow_or_con: uploader_name[0].downcase
    )
  end

  def source_title
    site = @site || user.try(:site) || Site.default
    return site.name if self.subtype.blank?
    t = if subtype == "PicasaPhoto" || is_a?( PicasaPhoto )
      "Google"
    end
    t ||= subtype.gsub(/Photo$/, '').underscore.humanize.titleize
    t
  end

  def to_observation(options = {})
    o = Observation.new(:user => user)
    o.observation_photos.build(:photo => self)
    tags = to_tags( with_title: true, with_file_name: true )
    if metadata
      if !metadata[:gps_latitude].blank? && !metadata[:gps_latitude].to_f.nan?
        o.latitude = metadata[:gps_latitude].to_f
        if metadata[:gps_latitude_ref].to_s == 'S' && o.latitude > 0
          o.latitude = o.latitude * -1
        end
      end
      if !metadata[:gps_longitude].blank? && !metadata[:gps_longitude].to_f.nan?
        o.longitude = metadata[:gps_longitude].to_f
        if metadata[:gps_longitude_ref].to_s == 'W' && o.longitude > 0
          o.longitude = o.longitude * -1
        end
      end
      begin
        if !metadata[:gps_h_positioning_error].blank? && !metadata[:gps_h_positioning_error].to_f.nan?
          o.positional_accuracy = metadata[:gps_h_positioning_error].to_i
        end
      rescue FloatDomainError
        # Apparently GPS Horizontal Positioning Error can be infinity.
        # Let's just ignore photos of the entire Universe
      end
      if (o.latitude && o.latitude.abs > 90) || (o.longitude && o.longitude.abs > 180)
        o.latitude = nil
        o.longitude = nil
      end
      if o.georeferenced?
        o.place_guess = o.system_places.sort_by{|p| p.bbox_area || 0}.map(&:name).join(', ')
      end
      if capture_time = (metadata[:date_time_original] || metadata[:date_time_digitized])
        o.set_time_zone
        o.time_observed_at = capture_time
        # Force the time to be in the time zone, b/c the value from EXIFR will
        # be in the system time zone, regardless of what time zone info might
        # be in the photo metadata. See
        # https://github.com/MikeKovarik/exifr/issues/84#issuecomment-1004691190
        o.set_time_in_time_zone
        if o.time_observed_at
          o.observed_on_string = o.time_observed_at.in_time_zone( o.time_zone || user.time_zone ).strftime("%Y-%m-%d %H:%M:%S")
          o.observed_on = o.time_observed_at.to_date
        end
      end
    end

    o.taxon = to_taxon
    if o.taxon && !tags.blank?
      tags = tags.map(&:downcase)
      o.species_guess = o.taxon.taxon_names.detect{|tn| tags.include?(tn.name.downcase)}.try(:name)
      o.species_guess ||= o.taxon.default_name.try(:name)
    elsif metadata && metadata[:dc] && !metadata[:dc][:title].blank?
      o.species_guess = metadata[:dc][:title].to_sentence.strip
    end
    if o.species_guess.blank?
      o.species_guess = nil
    end
    candidate_description = nil
    if metadata && metadata[:dc] && !metadata[:dc][:description].blank?
      candidate_description = [metadata[:dc][:description]].flatten.to_sentence.strip
    end
    if candidate_description.blank? && metadata && metadata[:image_description]
      if metadata[:image_description].is_a?(Array)
        candidate_description = metadata[:image_description].to_sentence
      elsif metadata[:image_description].is_a?(String)
        candidate_description = metadata[:image_description]
      end
    end
    if candidate_description
      candidate_description = candidate_description.strip
      o.description = candidate_description unless BRANDED_DESCRIPTIONS.include?( candidate_description )
    end

    if metadata
      o.build_observation_fields_from_tags(to_tags)
      o.tag_list = to_tags
    end
    o
  end

  def to_tags(options = {})
    tags = []
    if !metadata.blank? && !metadata[:dc].blank?
      tags += [metadata[:dc][:subject]].flatten.reject(&:blank?).map(&:strip)
      if options[:with_title] && !metadata[:dc][:title].blank?
        tags += [metadata[:dc][:title]].flatten.reject(&:blank?).map(&:strip)
      end
    end
    if options[:with_file_name] && file.file? && !file.original_filename.blank?
      # every string of letters except underscores (NOT not-words, underscores,
      # or numbers). Ignore the last since it's almost always a file extension
      # Note that I'm trying to handle unicode characters here, but there's
      # still a high chance of encoding weirdness happening
      words = file.original_filename.scan(/[\p{L}\p{M}\'\’]+/)
      words = words.reject do |word|
        word.size < 4 || word =~ /^original|img|inat|dsc.?|jpe?g|png|gif|open-uri$/i
      end
      # Collect all combinations of these words from 1-word combinations up to
      # the combination that includes all words. Note that a combination
      # preserves order, unlike permutations
      tags += ( 1..words.size ).map {|i|
        words.combination( i ).to_a.map{|c| c.join( " " ) }
      }.flatten
    end
    tags
  end

  def to_taxa(options = {})
    tags = to_tags( with_title: true, with_file_name: true )
    return [] if tags.blank?
    Taxon.tags_to_taxa(tags, options).compact
  end

  def rotate!(degrees = 90)
    reset_file_from_original
    self.rotation = degrees
    self.rotation -= 360 if self.rotation >= 360
    self.rotation += 360 if self.rotation <= -360
    self.file.reprocess!
    self.save
  end

  def extract_dimensions(style)
    if file? && tempfile = file.queued_for_write[style]
      if sizes = FastImage.size(tempfile)
        return { width: sizes[0],
                 height: sizes[1] }
      end
    end
  end

  def s3_client
    return unless CONFIG.usingS3
    s3_credentials = LocalPhoto.new.file.s3_credentials
    ::Aws::S3::Client.new(
      access_key_id: s3_credentials[:access_key_id],
      secret_access_key: s3_credentials[:secret_access_key],
      region: LocalPhoto.s3_region
    )
  end

  def mark_observations_as_updated
    observations.each do |o|
      o.mark_as_updated
    end
  end

  def prune_odp_duplicates( options = { } )
    return unless in_public_s3_bucket?
    client = options[:s3_client] || LocalPhoto.new.s3_client
    static_bucket = LocalPhoto.s3_bucket
    # check the static bucket for files for this photo
    s3_objects = client.list_objects( bucket: static_bucket, prefix: "photos/#{ id }/" )
    images = s3_objects.contents
    return unless images.any?
    puts "deleting photo #{id} [#{images.size} files] from S3"
    # delete the duplicates in the static bucket
    client.delete_objects( bucket: static_bucket, delete: { objects: images.map{|s| { key: s.key } } } )
  end

  def self.prune_odp_duplicates_batch( min_id, max_id )
    s3_client = LocalPhoto.new.s3_client
    LocalPhoto.
      where( "id >= ?", min_id ).
      where( "id < ?", max_id ).
      find_each( batch_size: 100 ) do |lp|
      lp.prune_odp_duplicates( s3_client: s3_client )
    end
  end

  private

  def self.move_to_appropriate_bucket( p )
    return unless LocalPhoto.odp_s3_bucket_enabled?
    return unless photo = LocalPhoto.find_by_id( p )
    return unless photo.is_a?( LocalPhoto )
    return unless photo.photo_bucket_should_be_changed?

    photo_started_in_public_s3_bucket = photo.in_public_s3_bucket?
    s3_client = photo.s3_client
    source_domain = LocalPhoto.s3_host_alias( photo_started_in_public_s3_bucket )
    target_domain = LocalPhoto.s3_host_alias( !photo_started_in_public_s3_bucket )
    source_bucket = LocalPhoto.s3_bucket( photo_started_in_public_s3_bucket )
    target_bucket = LocalPhoto.s3_bucket( !photo_started_in_public_s3_bucket )
    target_acl = LocalPhoto.s3_permissions( !photo_started_in_public_s3_bucket )

    # an additional check to make sure the photo URLs contain the expected domain.
    # Later there will be a string substitution replacing the source domain with
    # the target domain
    return unless photo.file_prefix && photo.file_prefix.prefix.include?( source_domain )

    # fetch list of files at the source
    images = LocalPhoto.aws_images_from_bucket( s3_client, source_bucket, photo )
    return if images.blank?

    # copy them over to the new target and confirm they arrived at the target
    moved_successfully = LocalPhoto.move_images_between_buckets(
      s3_client, photo, images, source_bucket, target_bucket, target_acl )

    if moved_successfully
      # Update the photo URLs in the DB. Do this before deleting the originals
      # in case there's some failure and we're not left with photo URLs pointing
      # to files that were deleted

      # override the photo s3_account so its URLs will point to the new bucket
      photo.s3_account = photo_started_in_public_s3_bucket ? nil : "public"
      photo.update_column( :file_prefix_id, FilePrefix.id_for_prefix( photo.parse_url_prefix ) )
      photo.reload

      # if the photo is being removed as a result of a flag being applied,
      # then remove it from the source bucket
      if photo.flags.detect{ |f| !f.resolved? }
        LocalPhoto.delete_images_from_bucket( s3_client, source_bucket, images )
      end
      # mark the observation as being updated, re-index only the updated_at column
      photo.mark_observations_as_updated
    else
      # move failed, so remove any files that did get copied to the target before the failure
      LocalPhoto.delete_images_from_bucket( s3_client, target_bucket, images )
    end
  end

  def self.aws_images_from_bucket( client, bucket, photo )
    begin
      s3_objects = client.list_objects( bucket: bucket, prefix: "photos/#{ photo.id }/" )
      images = s3_objects.contents
      if !( s3_objects && s3_objects.data &&
        s3_objects.data.is_a?( Aws::S3::Types::ListObjectsOutput ) && images.any? )
        return []
      end
    rescue
      # failed to fetch list of photo files, so just return
      return false
    end
    images
  end

  def self.move_images_between_buckets( s3_client, photo, source_images, source_bucket, target_bucket, target_acl )
    begin
      source_images.each do |image|
        puts "Copying #{ image.key }..."
        key = image.key
        s3_client.copy_object(
          bucket: target_bucket,
          copy_source: "#{ source_bucket }/#{ key }",
          key: image.key,
          acl: target_acl
        )
      end
    rescue
      # failed to copy all photo files to the new bucket
      return false
    end

    # verify all source images made it to the target, and they they are seemingly identical
    target_images = LocalPhoto.aws_images_from_bucket( s3_client, target_bucket, photo )
    return false if target_images.blank?
    source_images.each do |source_image|
      target_image = target_images.find{ |target| target.key == source_image.key }
      return false unless target_image
      return false unless target_image.etag == source_image.etag
      return false unless target_image.size == source_image.size
    end
    true
  end

  def self.delete_images_from_bucket( s3_client, delete_from_bucket, images )
    begin
      s3_client.delete_objects(
        bucket: delete_from_bucket,
        delete: {
          objects: images.map{ |image| { key: image.key } }
        }
      )
    rescue
      # failed to delete photos
      return false
    end
    true
  end

end
