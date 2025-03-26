# frozen_string_literal: true

class OauthApplication < Doorkeeper::Application
  has_many :observations
  has_many :user_installations
  has_attached_file :image,
    styles: { medium: "300x300>", thumb: "100x100>", mini: "16x16#" },
    default_url: "/attachment_defaults/:class/:style.png",
    storage: :s3,
    s3_credentials: "#{Rails.root}/config/s3.yml",
    s3_protocol: CONFIG.s3_protocol || "https",
    s3_host_alias: CONFIG.s3_host || CONFIG.s3_bucket,
    s3_region: CONFIG.s3_region,
    bucket: CONFIG.s3_bucket,
    path: "oauth_applications/:id-:style.:extension",
    url: ":s3_alias_url"
  invalidate_cloudfront_caches :image, "oauth_applications/:id-*"

  before_create :set_scopes

  validates_attachment_content_type :image, :content_type => [/jpe?g/i, /png/i, /gif/i, /octet-stream/],
    :message => "must be JPG, PNG, or GIF"
  validate :redirect_uri_has_no_params

  WEB_APP_ID = 0
  ANDROID_APP_NAME = "iNaturalist Android App"
  IPHONE_APP_NAME = "iNaturalist iPhone App"
  SEEK_APP_NAME = "Seek"
  INAT_NEXT_APP_NAME = "iNat Next"

  def redirect_uri_has_no_params
    if redirect_uri.to_s.split( "?" ).size > 1
      errors.add( :redirect_uri, "cannot have a query string" )
    end
  end

  def self.inaturalist_android_app
    @@inaturalist_android_app ||= OauthApplication.where( name: ANDROID_APP_NAME ).first
  end

  def self.inaturalist_iphone_app
    @@inaturalist_iphone_app ||= OauthApplication.where( name: IPHONE_APP_NAME ).first
  end

  def self.seek_app
    @@seek_app ||= OauthApplication.where( name: SEEK_APP_NAME ).first
  end

  def self.inat_next_app
    @@inat_next_app ||= OauthApplication.where( name: INAT_NEXT_APP_NAME ).first
  end

  def set_scopes
    self.scopes = Doorkeeper.configuration.default_scopes if self.scopes.blank?
    true
  end
end
