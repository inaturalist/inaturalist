class Site < ActiveRecord::Base
  has_many :observations, inverse_of: :site
  has_many :users, inverse_of: :site
  has_many :site_admins, inverse_of: :site
  has_many :posts, as: :parent, dependent: :destroy
  has_many :journal_posts, class_name: "Post", as: :parent, dependent: :destroy
  has_many :announcements, inverse_of: :site, dependent: :destroy

  scope :live, -> { where(draft: false) }
  scope :drafts, -> { where(draft: true) }

  # shortened version of the name
  preference :site_name_short, :string

  # Email addresses
  preference :email_admin, :string
  preference :email_noreply, :string
  preference :email_help, :string
  preference :email_info, :string

  preference :contact_first_name, :string
  preference :contact_last_name, :string
  preference :contact_organization, :string
  preference :contact_position, :string
  preference :contact_address, :string
  preference :contact_city, :string
  preference :contact_admin_area, :string
  preference :contact_postal_code, :string
  preference :contact_country, :string
  preference :contact_phone, :string
  preference :contact_email, :string
  preference :contact_url, :string

  preference :locale, :string, :default => "en"

  # default bounds for most maps, including /observations/new and the home page. Defaults to the whole world
  preference :geo_swlat, :string
  preference :geo_swlng, :string
  preference :geo_nelat, :string
  preference :geo_nelng, :string

  preference :map_about_url, :string
  preference :legacy_rest_auth_key, :string

  # default place ID for place filters. Presently only used on /places, but use may be expanded
  belongs_to :place, :inverse_of => :sites

  # header logo, should be at least 118x22
  if Rails.env.production?
    has_attached_file :logo,
      :storage => :s3,
      :s3_credentials => "#{Rails.root}/config/s3.yml",
      :s3_protocol => CONFIG.s3_protocol || "https",
      :s3_host_alias => CONFIG.s3_host || CONFIG.s3_bucket,
      :bucket => CONFIG.s3_bucket,
      :path => "sites/:id-logo.:extension",
      :url => ":s3_alias_url",
      :default_url => "logo-small.gif"
    invalidate_cloudfront_caches :logo, "sites/:id-logo.*"
  else
    has_attached_file :logo,
      :path => ":rails_root/public/attachments/sites/:id-logo.:extension",
      :url => "/attachments/sites/:id-logo.:extension",
      :default_url => "logo-small.gif"
  end
  validates_attachment_content_type :logo, :content_type => [/jpe?g/i, /png/i, /gif/i, /octet-stream/, /svg/], 
    :message => "must be JPG, PNG, SVG, or GIF"

  # large square branding image that appears on pages like /login. Should be 300 px wide and about that tall
  if Rails.env.production?
    has_attached_file :logo_square,
      :storage => :s3,
      :s3_credentials => "#{Rails.root}/config/s3.yml",
      :s3_protocol => CONFIG.s3_protocol || "https",
      :s3_host_alias => CONFIG.s3_host || CONFIG.s3_bucket,
      :bucket => CONFIG.s3_bucket,
      :path => "sites/:id-logo_square.:extension",
      :url => ":s3_alias_url",
      :default_url => "bird.png"
    invalidate_cloudfront_caches :logo_square, "sites/:id-logo_square.*"
  else
    has_attached_file :logo_square,
      :path => ":rails_root/public/attachments/sites/:id-logo_square.:extension",
      :url => "/attachments/sites/:id-logo_square.:extension",
      :default_url => "bird.png"
  end
  validates_attachment_content_type :logo_square, :content_type => [/jpe?g/i, /png/i, /gif/i, /octet-stream/], 
    :message => "must be JPG, PNG, or GIF"

  # large square branding image that appears on pages like /login. Should be 300 px wide and about that tall
  if Rails.env.production?
    has_attached_file :logo_email_banner,
      :storage => :s3,
      :s3_credentials => "#{Rails.root}/config/s3.yml",
      :s3_protocol => CONFIG.s3_protocol || "https",
      :s3_host_alias => CONFIG.s3_host || CONFIG.s3_bucket,
      :bucket => CONFIG.s3_bucket,
      :path => "sites/:id-logo_email_banner.:extension",
      :url => ":s3_alias_url",
      :default_url => "inat_email_banner.png"
    invalidate_cloudfront_caches :logo_email_banner, "sites/:id-logo_email_banner.*"
  else
    has_attached_file :logo_email_banner,
      :path => ":rails_root/public/attachments/sites/:id-logo_email_banner.:extension",
      :url => "/attachments/sites/:id-logo_email_banner.:extension",
      :default_url => "inat_email_banner.png"
  end
  validates_attachment_content_type :logo_email_banner, :content_type => [/jpe?g/i, /png/i, /gif/i, /octet-stream/], :message => "must be JPG, PNG, or GIF"
      
  # CSS file to override default styles
  if Rails.env.production?
    has_attached_file :stylesheet,
      :storage => :s3,
      :s3_credentials => "#{Rails.root}/config/s3.yml",
      :s3_protocol => CONFIG.s3_protocol || "https",
      :s3_host_alias => CONFIG.s3_host || CONFIG.s3_bucket,
      :bucket => CONFIG.s3_bucket,
      :path => "sites/:id-stylesheet.css",
      :url => ":s3_alias_url"
    invalidate_cloudfront_caches :stylesheet, "sites/:id-stylesheet.css"
  else
    has_attached_file :stylesheet,
      :path => ":rails_root/public/attachments/sites/:id-stylesheet.css",
      :url => "/attachments/sites/:id-stylesheet.css"
  end

  validates_attachment_content_type :stylesheet, content_type: [
    "text/css", 
    # Not great, but probably ok here where only site admins can add the file.
    # Underlying problem is that we force all validations to depend on the file
    # commant (see paperclip initializer) and it reads CSS as plain/text
    "text/plain"
  ], message: "must be CSS"

  # URL where visitors can learn more about the site
  preference :about_url, :string

  # URL where visitors can get help using the site
  preference :help_url, :string, :default => "/pages/help"
  
  # URL where visitors can get started using the site
  preference :getting_started_url, :string, :default => "/pages/getting+started"

  # URL where press can learn more about the site and get assets
  preference :press_url, :string

  preference :feedback_url, :string
  preference :terms_url, :string, :default => "/pages/terms"
  preference :privacy_url, :string, :default => "/pages/privacy"
  preference :developers_url, :string, :default => "/pages/developers"
  preference :twitter_url, :string
  preference :iphone_app_url, :string
  preference :android_app_url, :string
  preference :facebook_url, :string
  preference :twitter_url, :string
  preference :blog_url, :string

  preference :twitter_username, :string

  # Title of wiki page to use as the home page. Default will be the normal view in app/views/welcome/index
  preference :home_page_wiki_path, :string
  # Chunk of json represening customized home page wiki paths by locale. Yes,
  # we *could* use the preference gem's grouping here, but this is easier to
  # put in a form
  preference :home_page_wiki_path_by_locale, :string

  # site: only show obs added through this site
  # place: only show obs within the specified place's boundary
  # bounding_box: only show obs within the bounding box
  OBSERVATIONS_FILTERS = %w(site place bounding_box)
  OBSERVATIONS_FILTERS.each do |f|
    const_set "OBSERVATIONS_FILTERS_#{f.upcase.gsub(/\-/, '_')}", f
  end
  preference :site_observations_filter, :string, default: OBSERVATIONS_FILTERS_PLACE

  # Used in places like /people
  preference :site_only_users, :boolean, :default => false

  # iOS app ID. Used to display header notice about app in mobile views
  preference :ios_app_id, :string

  # If you'd prefer the default taxon ranges to come from a particular Source, set the source ID here
  # taxon_range_source_id: 7538
  belongs_to :taxon_range_source, class_name: "Source", foreign_key: "source_id"

  # google_analytics, http://www.google.com/analytics/
  preference :google_analytics_tracker_id, :string

  # google webmaster tools, http://www.google.com/webmasters/tools/
  preference :google_webmaster_verification, :string

  # Configure taxon description callbacks. taxa/show will try to show
  # species descriptions from these sources in this order, trying the next
  # if one fails. You can see all the available describers in
  # lib/taxon_describers/lib/taxon_describers
  preference :taxon_describers_array, :string

  # Ratatosk is an internal library for looking up external taxonomy info.
  # By default it uses all registered name providers, but you can
  # configure it here to use a subset
  preference :ratatosk_name_providers_array, :string

  preference :custom_logo, :text
  preference :custom_footer, :text
  preference :custom_secondary_footer, :text
  preference :custom_email_footer_leftside, :text
  preference :custom_email_footer_rightside, :text

  # Whether this site prefers https
  preference :ssl, :boolean

  def self.default
    Site.first
  end

  def to_s
    "<Site #{id} #{url}>"
  end

  def contact
    {
      first_name: contact_first_name,
      last_name: contact_last_name,
      organization: contact_organization,
      position: contact_position,
      address: contact_address,
      city: contact_city,
      admin_area: contact_admin_area,
      postal_code: contact_postal_code,
      country: contact_country,
      email: contact_email,
      url: contact_url
    }
  end

  def respond_to?(method, include_all=false)
    preferences.keys.include?(method.to_s) ? true : super
  end

  def method_missing(method, *args, &block)
    preferences.keys.include?(method.to_s) ? preferences[method.to_s] : super
  end

  def editable_by?(user)
    user && user.is_admin?
  end

  def icon_url
    return nil unless logo_square.file?
    logo_square.url
  end

  def home_page_wiki_path_by_locale( locale )
    return nil if preferred_home_page_wiki_path_by_locale.blank?
    paths = JSON.parse( preferred_home_page_wiki_path_by_locale ) rescue {}
    unless path = paths[ locale.to_s ]
      path = paths[ locale.to_s.split("-")[0] ]
    end
    path
  end

  def coordinate_systems
    return if coordinate_systems_json.blank?
    systems = JSON.parse( coordinate_systems_json ) rescue { }
    systems.blank? ? nil : systems
  end

  def bounds?
    !geo_swlat.blank? && !geo_swlng.blank? &&
    !geo_nelat.blank? && !geo_nelng.blank?
  end

  def bounds
    return unless bounds?
    { swlat: geo_swlat.to_f, swlng: geo_swlng.to_f,
      nelat: geo_nelat.to_f, nelng: geo_nelng.to_f }
  end

  def ratatosk_name_providers
    return if ratatosk_name_providers_array.blank?
    ratatosk_name_providers_array.split( "," ).map( &:strip )
  end


  def taxon_describers
    return if taxon_describers_array.blank?
    taxon_describers_array.split( "," ).map( &:strip )
  end

end
