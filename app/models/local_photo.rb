class LocalPhoto < Photo
  Photo.descendent_classes ||= []
  Photo.descendent_classes << self
  
  before_create :set_defaults
  after_create :set_native_photo_id, :set_urls
  
  has_attached_file :file, 
    :styles => {
      :original => "2048x2048>",
      :large => "1024x1024>", :medium => "500x500>", :small => "240x240>", 
      :thumb => "100x100#", :square => "75x75#" },
    :storage => :s3,
    :s3_credentials => "#{Rails.root}/config/s3.yml",
    :url => ":s3_alias_url",
    :s3_host_alias => INAT_CONFIG['s3_bucket'],
    :path => "photos/:id/:style.:extension",
    :bucket => INAT_CONFIG['s3_bucket']
    
    # Uncomment this to switch to local storage.  Sometimes useful for 
    # testing w/o ntwk
    # :path => ":rails_root/public/attachments/:class/:attachment/:id/:style/:basename.:extension",
    # :url => "/attachments/:class/:attachment/:id/:style/:basename.:extension",
    # :default_url => "/attachment_defaults/:class/:attachment/defaults/:style.png"
    
  validates_presence_of :user
  validates_attachment_presence :file
  validates_attachment_size :file, :less_than => 3.megabytes
  
  def set_defaults
    self.native_page_url = url_for(observations.first) unless observations.blank?
    self.native_username = user.login
    self.license = Photo::COPYRIGHT
  end
  
  def set_urls
    styles = %w(original large medium small thumb square)
    updates = [styles.map{|s| "#{s}_url = ?"}.join(', ')]
    updates += styles.map {|s| file.url(s)}
    Photo.update_all(updates, ["id = ?", id])
    true
  end
  
  def set_native_photo_id
    update_attribute(:native_photo_id, id)
  end
  
end