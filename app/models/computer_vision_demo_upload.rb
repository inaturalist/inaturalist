class ComputerVisionDemoUpload < ActiveRecord::Base

  serialize :metadata

  has_attached_file :photo,
    styles: {
      original: "2048x2048>",
      thumbnail: "300x300>"
    },
    path: ":rails_root/public/attachments/:class/:id/:style.:content_type_extension",
    url: "/attachments/:class/:id/:style.:content_type_extension",
    default_url: ""
  validates_attachment_content_type :photo,
    content_type: [ /jpe?g/i, /png/i, /gif/i, /octet-stream/ ],
    message: "must be JPG, PNG, or GIF"

  after_create :set_urls

  def set_urls
    self.original_url = photo.url(:original)
    self.thumbnail_url = photo.url(:thumbnail)
    save
  end

  def photo=(data)
    self.photo.assign(data)
    if data.is_a?(ActionDispatch::Http::UploadedFile)
      extract_metadata(data.path)
    end
  end

  def extract_metadata( path )
    return unless path
    self.metadata ||= { }
    begin
      if photo_content_type =~ /jpe?g/i && exif = EXIFR::JPEG.new( path )
        self.metadata.merge!( exif.to_hash )
        xmp = XMP.parse( exif )
        if xmp && xmp.respond_to?( :dc ) && !xmp.dc.nil?
          self.metadata[:dc] = { }
          xmp.dc.attributes.each do |dcattr|
            begin
              unless xmp.dc.send(dcattr).blank?
                self.metadata[:dc][dcattr.to_sym] = xmp.dc.send( dcattr )
              end
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
    self.metadata = self.metadata.force_utf8
  end

  def to_observation(options = {})
    o = Observation.new
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
    o
  end

end
