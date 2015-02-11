#encoding: utf-8
class LocalPhoto < Photo
  Photo.descendent_classes ||= []
  Photo.descendent_classes << self
  
  before_create :set_defaults
  after_create :set_native_photo_id, :set_urls
  
  # only perform EXIF-based rotation on mobile app contributions
  image_convert_options = Proc.new {|record|
    record.rotation.blank? && record.mobile? ? "-auto-orient -strip" : "-strip"
  }
  
  has_attached_file :file, 
    :styles => {
      :original => {:geometry => "2048x2048>",  :auto_orient => false, :processors => [:rotator] },
      :large    => {:geometry => "1024x1024>",  :auto_orient => false },
      :medium   => {:geometry => "500x500>",    :auto_orient => false },
      :small    => {:geometry => "240x240>",    :auto_orient => false, :processors => [:deanimator] },
      :thumb    => {:geometry => "100x100>",    :auto_orient => false, :processors => [:deanimator] },
      :square   => {:geometry => "75x75#",      :auto_orient => false, :processors => [:deanimator] }
    },
    :convert_options => {
      :original => image_convert_options,
      :large  => image_convert_options,
      :medium => image_convert_options,
      :small  => image_convert_options,
      :thumb  => image_convert_options,
      :square => image_convert_options
    },
    :storage => :s3,
    :s3_credentials => "#{Rails.root}/config/s3.yml",
    :s3_host_alias => CONFIG.s3_bucket,
    :bucket => CONFIG.s3_bucket,
    :path => "photos/:id/:style.:extension",
    :url => ":s3_alias_url",
    :default_url => "/attachment_defaults/:class/:style.png"
    # # Uncomment this to switch to local storage.  Sometimes useful for 
    # # testing w/o ntwk
    # :path => ":rails_root/public/attachments/:class/:attachment/:id/:style/:basename.:extension",
    # :url => "/attachments/:class/:attachment/:id/:style/:basename.:extension",
    # :default_url => "/attachment_defaults/:class/:attachment/defaults/:style.png"
  
  process_in_background :file
  after_post_process :set_urls, :expire_observation_caches
  after_save :expire_observation_caches
    
  validates_presence_of :user
  validates_attachment_content_type :file, :content_type => [/jpe?g/i, /png/i, /gif/i, /octet-stream/], 
    :message => "must be JPG, PNG, or GIF"

  attr_accessor :rotation
  
  # I think this may be impossible using delayed_paperclip
  # validates_attachment_presence :file
  # validates_attachment_size :file, :less_than => 5.megabytes
  
  def set_defaults
    self.native_username ||= user.login
    self.native_realname ||= user.name
    true
  end

  def file=(data)
    self.file.assign(data)
    begin
      if file_content_type =~ /jpe?g/i && exif = EXIFR::JPEG.new(data.path)
        self.metadata = exif.to_hash
        xmp = XMP.parse(exif)
        if xmp && xmp.respond_to?(:dc) && !xmp.dc.nil?
          self.metadata[:dc] = {}
          xmp.dc.attributes.each do |dcattr|
            begin
              self.metadata[:dc][dcattr.to_sym] = xmp.dc.send(dcattr) unless xmp.dc.send(dcattr).blank?
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
    end
  end
  
  def set_urls
    styles = %w(original large medium small thumb square)
    updates = [styles.map{|s| "#{s}_url = ?"}.join(', ')]
    updates += styles.map do |s|
      url = file.url(s)
      url =~ /http/ ? url : FakeView.uri_join(FakeView.root_url, url).to_s
    end
    updates[0] += ", native_page_url = '#{FakeView.photo_url(self)}'" if native_page_url.blank?
    Photo.where(id: id).update_all(updates)
    true
  end

  def repair
    self.file.reprocess!
    set_urls
    [self, {}]
  end

  def attribution
    if [user.name, user.login].include?(native_realname)
      super
    else
      "#{super}, uploaded by #{user.try_methods(:name, :login)}"
    end
  end
  
  def expire_observation_caches
    ctrl = ActionController::Base.new
    observation_photos.all.each do |op|
      Observation.expire_components_for(op.observation_id)
    end
    true
  rescue => e
    Airbrake.notify(e)
    true
  end
  
  def set_native_photo_id
    update_attribute(:native_photo_id, id)
    true
  end

  def source_title
    SITE_NAME
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
      photo_taxa = to_taxa
      candidate = photo_taxa.detect(&:species_or_lower?) || photo_taxa.first
      if photo_taxa.detect{|t| t.name == candidate.name && t.id != candidate.id}
        o.species_guess = candidate.name
      else
        o.taxon = candidate
      end
      if o.taxon
        tags = to_tags.map(&:downcase)
        o.species_guess = o.taxon.taxon_names.detect{|tn| tags.include?(tn.name.downcase)}.try(:name)
        o.species_guess ||= o.taxon.default_name.try(:name)
      elsif !metadata[:dc][:title].blank?
        o.species_guess = metadata[:dc][:title].to_sentence.strip
      end
      if o.species_guess.blank?
        o.species_guess = nil
      end
      o.description = metadata[:dc][:description].to_sentence unless metadata[:dc][:description].blank?
      o.build_observation_fields_from_tags(to_tags)
    end
    o
  end

  def to_tags
    return [] if metadata.blank? || metadata[:dc].blank?
    [metadata[:dc][:title], metadata[:dc][:subject]].flatten.compact.map(&:strip)
  end

  def to_taxa(options = {})
    tags = to_tags
    return [] if tags.blank?
    Taxon.tags_to_taxa(tags, options).compact
  end

  def rotate!(degrees = 90)
    self.rotation = degrees
    self.rotation -= 360 if self.rotation >= 360
    self.rotation += 360 if self.rotation <= -360
    self.file.post_processing = true
    self.file.reprocess!
    self.save
  end
  
end
