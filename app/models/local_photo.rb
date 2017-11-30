#encoding: utf-8
class LocalPhoto < Photo
  before_create :set_defaults
  after_create :set_native_photo_id, :set_urls
  
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

  if Rails.env.production?
    has_attached_file :file, file_options.merge(
      storage: :s3,
      s3_credentials: "#{Rails.root}/config/s3.yml",
      s3_protocol: CONFIG.s3_protocol || "https",
      s3_host_alias: CONFIG.s3_host || CONFIG.s3_bucket,
      bucket: CONFIG.s3_bucket,
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
      path: ":rails_root/public/attachments/:class/:attachment/:id/:style/:basename.:content_type_extension",
      url: "/attachments/:class/:attachment/:id/:style/:basename.:content_type_extension",
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

  # LocalPhotos with subtypes are former remote photos, and subtype
  # is the former subclass. Those subclasses don't validate :user
  validates_presence_of :user, unless: :subtype
  validates_attachment_content_type :file, :content_type => [/jpe?g/i, /png/i, /gif/i, /octet-stream/], 
    :message => "must be JPG, PNG, or GIF"

  attr_accessor :rotation, :skip_delay, :skip_cloudfront_invalidation

  BRANDED_DESCRIPTIONS = [
    "OLYMPUS DIGITAL CAMERA",
    "SONY DSC",
    "MOULTRIE DIGITAL GAME CAMERA",
    "<KENOX S1050 / Samsung S1050>",
    "KODAK Digital Still Camera",
    "DIGITAL CAMERA",
    "SAMSUNG CAMERA PICTURES"
  ]
  
  # I think this may be impossible using delayed_paperclip
  # validates_attachment_presence :file
  # validates_attachment_size :file, :less_than => 5.megabytes
  
  def set_defaults
    if user
      self.native_username ||= user.login
      self.native_realname ||= user.name
    end
    true
  end

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
    metadata = self.metadata.to_h.clone || {}
    metadata[:dimensions] ||= { }
    begin
      file.styles.keys.each do |style|
        metadata[:dimensions][style] = extract_dimensions(style)
      end
      if file_content_type =~ /jpe?g/i && exif = EXIFR::JPEG.new(path || file.queued_for_write[:original].path)
        metadata.merge!(exif.to_hash)
        xmp = XMP.parse(exif)
        if xmp && xmp.respond_to?(:dc) && !xmp.dc.nil?
          metadata[:dc] = {}
          xmp.dc.attributes.each do |dcattr|
            begin
              metadata[:dc][dcattr.to_sym] = xmp.dc.send(dcattr) unless xmp.dc.send(dcattr).blank?
            rescue ArgumentError
              # XMP does this for some DC attributes, not sure why
            end
          end
        end
      end
    rescue EXIFR::MalformedImage, EOFError => e
      Rails.logger.error "[ERROR #{Time.now}] Failed to parse EXIF for #{self}: #{e}"
    rescue NoMethodError => e
      raise e unless e.message =~ /path.*StringIO/
      Rails.logger.error "[ERROR #{Time.now}] Failed to parse EXIF for #{self}: #{e}"
    rescue TypeError => e
      raise e unless e.message =~ /no implicit conversion of Fixnum into String/
      Rails.logger.error "[ERROR #{Time.now}] Failed to parse EXIF for #{self}: #{e}"
    end
    metadata = metadata.force_utf8
    self.metadata = metadata
  end

  def set_urls
    styles = %w(original large medium small thumb square)
    updates = [styles.map{|s| "#{s}_url = ?"}.join(', ')]
    # the original_url will be blank when initially saving any file
    # by URL (cached remote photos). We want them to have placeholder
    # photos, so use a dummy LocalPhoto for initial photo URLs
    blank_file = LocalPhoto.new.file
    updates += styles.map do |s|
      url = file.queued_for_write[s].blank? ? file.url(s) : blank_file.url(s)
      url =~ /http/ ? url : FakeView.uri_join(FakeView.root_url, url).to_s
    end
    unless new_record?
      updates[0] += ", native_page_url = '#{FakeView.photo_url(self)}'" if native_page_url.blank?
    end
    Photo.where(id: id).update_all(updates)
    true
  end

  def reset_file_from_original
    interpolated_original_url = FakeView.image_url( self.file.url(:original) )
    
    # If we're using local file storage and using some kind of development-ish
    # setup, it probably means we're running a single server process, which
    # means running a HEAD request while *this* request is running is going to
    # cause problems, but it also means that the original file is *probably*
    # there so we can skip this file reset business.
    return if interpolated_original_url =~ /localhost/

    # If the original file is there under the current path, no need to do anything
    return if Photo.valid_remote_photo_url?( interpolated_original_url )
    
    # If it's not, check the old path
    old_interpolated_original_url = FakeView.image_url(
      Paperclip::Interpolations.interpolate("photos/:id/:style.:extension", self.file, "original")
    )
    url = if Photo.valid_remote_photo_url?( old_interpolated_original_url )
      old_interpolated_original_url
    
    # If it's not at the old path, use the cached original_url if it's not copyright infringement
    elsif original_url !~ /copyright/
      FakeView.image_url( original_url )

    # If this is a copyright violation AND we don't have access to an original file, we're screwed.
    else
      raise "We no longer have access to the original file."
    end

    io = open( URI.parse( url ) )
    Timeout::timeout(10) do
      self.file = (io.base_uri.path.split('/').last.blank? ? nil : io)
    end
  end

  def repair(options = {})
    reset_file_from_original
    self.file.reprocess!
    set_urls
    [self, {}]
  end

  def attribution
    if user.blank? || [user.name, user.login].include?(native_realname)
      super
    else
      "#{super}, uploaded by #{user.try_methods(:name, :login)}"
    end
  end
  
  def set_native_photo_id
    if subtype.blank?
      update_attribute(:native_photo_id, id)
    end
  end

  def source_title
    site = @site || user.try(:site) || Site.default
    self.subtype.blank? ? site.name :
      subtype.gsub(/Photo$/, '').underscore.humanize.titleize
  end

  def to_observation(options = {})
    o = Observation.new(:user => user)
    o.observation_photos.build(:photo => self)
    return o unless metadata
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
      o.set_time_in_time_zone
      if o.time_observed_at
        o.observed_on_string = o.time_observed_at.strftime("%Y-%m-%d %H:%M:%S")
        o.observed_on = o.time_observed_at.to_date
      end
    end
    unless metadata[:dc].blank?
      o.taxon = to_taxon
      if o.taxon
        tags = to_tags(with_title: true).map(&:downcase)
        o.species_guess = o.taxon.taxon_names.detect{|tn| tags.include?(tn.name.downcase)}.try(:name)
        o.species_guess ||= o.taxon.default_name.try(:name)
      elsif !metadata[:dc][:title].blank?
        o.species_guess = metadata[:dc][:title].to_sentence.strip
      end
      if o.species_guess.blank?
        o.species_guess = nil
      end
      candidate_description = nil
      unless metadata[:dc][:description].blank?
        candidate_description = [metadata[:dc][:description]].flatten.to_sentence.strip
      end
      if candidate_description.blank? && metadata[:image_description]
        if metadata[:image_description].is_a?(Array)
          candidate_description = metadata[:image_description].to_sentence
        elsif metadata[:image_description].is_a?(String)
          candidate_description = metadata[:image_description]
        end
      end
      o.description = candidate_description unless BRANDED_DESCRIPTIONS.include?( candidate_description )

      o.build_observation_fields_from_tags(to_tags)
      o.tag_list = to_tags
    end
    o
  end

  def to_tags(options = {})
    return [] if metadata.blank? || metadata[:dc].blank?
    @tags ||= [metadata[:dc][:subject]].flatten.reject(&:blank?).map(&:strip)
    tags = @tags
    tags += [metadata[:dc][:title]].flatten.reject(&:blank?).map(&:strip) if options[:with_title] && !metadata[:dc][:title].blank?
    tags
  end

  def to_taxa(options = {})
    tags = to_tags(with_title: true)
    return [] if tags.blank?
    Taxon.tags_to_taxa(tags, options).compact
  end

  def rotate!(degrees = 90)
    reset_file_from_original
    self.rotation = degrees
    self.rotation -= 360 if self.rotation >= 360
    self.rotation += 360 if self.rotation <= -360
    self.file.reprocess_without_delay!
    self.save
  end

  def processing?
    square_url.blank? || square_url.include?(LocalPhoto.new.file(:square))
  end

  def extract_dimensions(style)
    if file? && tempfile = file.queued_for_write[style]
      if sizes = FastImage.size(tempfile)
        return { width: sizes[0],
                 height: sizes[1] }
      end
    end
  end

  # this method was created for generating dimensions for
  # all existing images in S3 in mass. It was designed for
  # performance and not accuracy. It extrapolates the sizes of
  # all the styles from the original to save on HTTP requests.
  # Photo.extract_dimensions is the more exact method
  def extrapolate_dimensions_from_original
    return unless original_url
    if original_dimensions = FastImage.size(original_url)
      sizes = {
        original: {
          width: original_dimensions[0],
          height: original_dimensions[1]
        }
      }
      max_d = original_dimensions.max
      # extrapolate the scaled dimensions of the other sizes
      file.styles.each do |key, s|
        next if key.to_sym == :original
        if match = s.geometry.match(/([0-9]+)x([0-9]+)([^0-9])?/)
          style_sizes = {
            width: match[1].to_i,
            height: match[2].to_i
          }
          modifier = match[3]
          # the '#' modifier means the resulting image is exactly that size
          unless modifier == "#"
            ratio = (max_d < style_sizes[:width]) ?
              1 : (style_sizes[:width] / max_d.to_f)
            style_sizes[:width] = (sizes[:original][:width] * ratio).round
            style_sizes[:height] = (sizes[:original][:height] * ratio).round
          end
          sizes[key] = style_sizes
        end
      end
      sizes
    end
  end

end
