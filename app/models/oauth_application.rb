class OauthApplication < Doorkeeper::Application
  has_many :observations
  has_attached_file :image, 
    :styles => { :medium => "300x300>", :thumb => "100x100>", :mini => "16x16#" }, 
    :default_url => "/attachment_defaults/:class/:style.png",
    :storage => :s3,
    :s3_credentials => "#{Rails.root}/config/s3.yml",
    :s3_host_alias => CONFIG.s3_bucket,
    :bucket => CONFIG.s3_bucket,
    :path => "oauth_applications/:id-:style.:extension",
    :url => ":s3_alias_url"
  validates_attachment_content_type :image, :content_type => [/jpe?g/i, /png/i, /gif/i, /octet-stream/], 
    :message => "must be JPG, PNG, or GIF"
end
