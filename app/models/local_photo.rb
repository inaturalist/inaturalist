#encoding: utf-8
class LocalPhoto < Photo
  Photo.descendent_classes ||= []
  Photo.descendent_classes << self
  
  before_create :set_defaults
  after_create :set_native_photo_id, :set_urls
  
  # only perform EXIF-based rotation on mobile app contributions
  image_convert_options = Proc.new {|record|
    record.mobile? ? "-auto-orient -strip" : "-strip"
  }
  
  has_attached_file :file, 
    :styles => {
      :original => {:geometry => "2048x2048>",  :auto_orient => false },
      :large    => {:geometry => "1024x1024>",  :auto_orient => false },
      :medium   => {:geometry => "500x500>",    :auto_orient => false },
      :small    => {:geometry => "240x240>",    :auto_orient => false },
      :thumb    => {:geometry => "100x100>",    :auto_orient => false },
      :square   => {:geometry => "75x75#",      :auto_orient => false }
    },
    :convert_options => {
      :large  => image_convert_options,
      :medium => image_convert_options,
      :small  => image_convert_options,
      :thumb  => image_convert_options,
      :square => image_convert_options
    },
    :storage => :s3,
    :s3_credentials => "#{Rails.root}/config/s3.yml",
    :s3_host_alias => CONFIG.get(:s3_bucket),
    :bucket => CONFIG.get(:s3_bucket),
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
    
  validates_presence_of :user
  validates_attachment_content_type :file, :content_type => [/jpe?g/i, /png/i, /gif/i, /octet-stream/], 
    :message => "must be JPG, PNG, or GIF"
  
  # I think this may be impossible using delayed_paperclip
  # validates_attachment_presence :file
  # validates_attachment_size :file, :less_than => 5.megabytes
  
  def set_defaults
    self.native_username = user.login
    true
  end

  def file=(data)
    start_time = Time.now
    self.file.assign(data)
    if file_content_type =~ /jpe?g/i && exif = EXIFR::JPEG.new(data.path)
      begin
        self.metadata = exif.to_hash
        xmp = XMP.parse(exif)
        if xmp && xmp.respond_to?(:dc) && !xmp.dc.blank?
          self.metadata[:dc] = {}
          xmp.dc.attributes.each do |dcattr|
            begin
              self.metadata[:dc][dcattr.to_sym] = xmp.dc.send(dcattr) unless xmp.dc.send(dcattr).blank?
            rescue ArgumentError
              # XMP does this for some DC attributes, not sure why
            end
          end
        end
      rescue EXIFR::MalformedImage => e
        Rails.logger.error "[ERROR #{Time.now}] Failed to parse EXIF for #{@attachment.instance}: #{e}"
      end
    end
  end
  
  def set_urls
    styles = %w(original large medium small thumb square)
    updates = [styles.map{|s| "#{s}_url = ?"}.join(', ')]
    updates += styles.map {|s| file.url(s)}
    updates[0] += ", native_page_url = '#{FakeView.photo_url(self)}'"
    Photo.update_all(updates, ["id = ?", id])
    true
  end
  
  def expire_observation_caches
    ctrl = ActionController::Base.new
    observation_photos.all.each do |op|
      ctrl.expire_fragment(Observation.component_cache_key(op.observation_id, :for_owner => true))
      ctrl.expire_fragment(Observation.component_cache_key(op.observation_id))
    end
    true
  rescue => e
    puts "[DEBUG] Failed to expire obs caches for #{self}: #{e}"
    puts e.backtrace.join("\n")
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
    if metadata
      unless metadata[:gps_latitude].blank?
        o.latitude = metadata[:gps_latitude].to_f
        if metadata[:gps_latitude_ref].to_s == 'S' && o.latitude > 0
          o.latitude = o.latitude * -1
        end
      end
      unless metadata[:gps_longitude].blank?
        o.longitude = metadata[:gps_longitude].to_f
        if metadata[:gps_longitude_ref].to_s == 'W' && o.longitude > 0
          o.longitude = o.longitude * -1
        end
      end
      if o.georeferenced?
        o.place_guess = o.system_places.sort_by{|p| p.bbox_area || 0}.map(&:name).join(', ')
      end
      if capture_time = metadata[:date_time_original] || metadata[:date_time_digitized]
        o.set_time_zone
        o.time_observed_at = capture_time
        o.set_time_in_time_zone
        o.observed_on_string = o.time_observed_at.strftime("%Y-%m-%d %H:%M:%S")
        o.observed_on = o.time_observed_at.to_date
      end
      unless metadata[:dc].blank?
        o.taxon = to_taxon
        if o.taxon
          tags = to_tags.map(&:downcase)
          o.species_guess = o.taxon.taxon_names.detect{|tn| tags.include?(tn.name.downcase)}.try(:name)
        elsif !metadata[:dc][:title].blank?
          o.species_guess = metadata[:dc][:title].to_sentence.strip
        end
        o.description = metadata[:dc][:description].to_sentence unless metadata[:dc][:description].blank?
      end
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
  
end
