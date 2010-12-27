class LocalPhoto < Photo
  Photo.descendent_classes ||= []
  Photo.descendent_classes << self
  
  before_create :set_defaults
  after_create :set_native_photo_id, :set_urls
  
  attr_accessor :url_host # store host from controller on create
  
  has_attached_file :file, 
    :styles => {
      :large => "1024x1024>", :medium => "500x500>", :small => "240x240>", 
      :thumb => "100x100#", :square => "75x75#" },
    :path => ":rails_root/public/attachments/:class/:attachment/:id/:style/:basename.:extension",
    :url => "/attachments/:class/:attachment/:id/:style/:basename.:extension",
    :default_url => "/attachment_defaults/:class/:attachment/defaults/:style.png"
    
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
    styles.each do |style|
      updates << "#{url_host.sub(/\/$/, '')}#{file.url(style)}"
    end
    Photo.update_all(updates, ["id = ?", id])
    true
  end
  
  def set_native_photo_id
    update_attribute(:native_photo_id, id)
  end
  
end