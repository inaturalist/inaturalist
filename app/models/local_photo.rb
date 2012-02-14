class LocalPhoto < Photo
  Photo.descendent_classes ||= []
  Photo.descendent_classes << self
  
  before_create :set_defaults
  after_create :set_native_photo_id, :set_urls
  
  # only perform EXIF-based rotation on mobile app contributions
  image_convert_options = Proc.new {|record|
    record.mobile? ? "-auto-orient" : nil
  }
  
  has_attached_file :file, 
    :styles => {
      :original => "2048x2048>",
      :large => "1024x1024>", :medium => "500x500>", :small => "240x240>", 
      :thumb => "100x100>", :square => "75x75#" },
    :convert_options => {
      :large  => image_convert_options,
      :medium => image_convert_options,
      :small  => image_convert_options,
      :thumb  => image_convert_options,
      :square => image_convert_options
    },
    :storage => :s3,
    :s3_credentials => "#{Rails.root}/config/s3.yml",
    :s3_host_alias => INAT_CONFIG['s3_bucket'],
    :bucket => INAT_CONFIG['s3_bucket'],
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
  
  def set_urls
    styles = %w(original large medium small thumb square)
    updates = [styles.map{|s| "#{s}_url = ?"}.join(', ')]
    updates += styles.map {|s| file.url(s)}
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
  
end
