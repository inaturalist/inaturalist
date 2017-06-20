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

  # preference :flickr_key, :string
  # preference :flickr_shared_secret, :string
  # preference :facebook_app_id, :string

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

  # default place ID for place filters. Presently only used on /places, but use may be expanded
  belongs_to :place, :inverse_of => :sites

  # header logo, should be at least 118x22
  if Rails.env.production?
    has_attached_file :logo,
      :storage => :s3,
      :s3_credentials => "#{Rails.root}/config/s3.yml",
      :s3_protocol => "https",
      :s3_host_alias => CONFIG.s3_bucket,
      :bucket => CONFIG.s3_bucket,
      :path => "sites/:id-logo.:extension",
      :url => ":s3_alias_url",
      :default_url => "/assets/logo-small.gif"
    invalidate_cloudfront_caches :logo, "sites/:id-logo.*"
  else
    has_attached_file :logo,
      :path => ":rails_root/public/attachments/sites/:id-logo.:extension",
      :url => "#{ CONFIG.attachments_host }/attachments/sites/:id-logo.:extension",
      :default_url => FakeView.image_url("logo-small.gif")
  end
  validates_attachment_content_type :logo, :content_type => [/jpe?g/i, /png/i, /gif/i, /octet-stream/], 
    :message => "must be JPG, PNG, or GIF"

  # large square branding image that appears on pages like /login. Should be 300 px wide and about that tall
  if Rails.env.production?
    has_attached_file :logo_square,
      :storage => :s3,
      :s3_credentials => "#{Rails.root}/config/s3.yml",
      :s3_protocol => "https",
      :s3_host_alias => CONFIG.s3_bucket,
      :bucket => CONFIG.s3_bucket,
      :path => "sites/:id-logo_square.:extension",
      :url => ":s3_alias_url",
      :default_url => ->(i){ FakeView.image_url("bird.png") }
    invalidate_cloudfront_caches :logo_square, "sites/:id-logo_square.*"
  else
    has_attached_file :logo_square,
      :path => ":rails_root/public/attachments/sites/:id-logo_square.:extension",
      :url => "#{ CONFIG.attachments_host }/attachments/sites/:id-logo_square.:extension",
      :default_url => FakeView.image_url("bird.png")
  end
  validates_attachment_content_type :logo_square, :content_type => [/jpe?g/i, /png/i, /gif/i, /octet-stream/], 
    :message => "must be JPG, PNG, or GIF"

  # large square branding image that appears on pages like /login. Should be 300 px wide and about that tall
  if Rails.env.production?
    has_attached_file :logo_email_banner,
      :storage => :s3,
      :s3_credentials => "#{Rails.root}/config/s3.yml",
      :s3_protocol => "https",
      :s3_host_alias => CONFIG.s3_bucket,
      :bucket => CONFIG.s3_bucket,
      :path => "sites/:id-logo_email_banner.:extension",
      :url => ":s3_alias_url",
      :default_url => ->(i){ FakeView.image_url("inat_email_banner.png") }
    invalidate_cloudfront_caches :logo_email_banner, "sites/:id-logo_email_banner.*"
  else
    has_attached_file :logo_email_banner,
      :path => ":rails_root/public/attachments/sites/:id-logo_email_banner.:extension",
      :url => "#{ CONFIG.attachments_host }/attachments/sites/:id-logo_email_banner.:extension",
      :default_url => FakeView.image_url("inat_email_banner.png")
  end
  validates_attachment_content_type :logo_email_banner, :content_type => [/jpe?g/i, /png/i, /gif/i, /octet-stream/], :message => "must be JPG, PNG, or GIF"
      
  # CSS file to override default styles
  if Rails.env.production?
    has_attached_file :stylesheet,
      :storage => :s3,
      :s3_credentials => "#{Rails.root}/config/s3.yml",
      :s3_protocol => "https",
      :s3_host_alias => CONFIG.s3_bucket,
      :bucket => CONFIG.s3_bucket,
      :path => "sites/:id-stylesheet.css",
      :url => ":s3_alias_url"
    invalidate_cloudfront_caches :stylesheet, "sites/:id-stylesheet.css"
  else
    has_attached_file :stylesheet,
      :path => ":rails_root/public/attachments/sites/:id-stylesheet.css",
      :url => "#{ CONFIG.attachments_host }/attachments/sites/:id-stylesheet.css"
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
  preference :help_url, :string, :default => FakeView.wiki_page_url("help")
  
  # URL where visitors can get started using the site
  preference :getting_started_url, :string, :default => FakeView.wiki_page_url("getting+started")

  # URL where press can learn more about the site and get assets
  preference :press_url, :string

  preference :feedback_url, :string
  preference :terms_url, :string, :default => FakeView.wiki_page_url("terms")
  preference :privacy_url, :string, :default => FakeView.wiki_page_url("privacy")
  preference :developers_url, :string, :default => FakeView.wiki_page_url("developers")
  preference :twitter_url, :string
  preference :facebook_url, :string
  preference :iphone_app_url, :string
  preference :android_app_url, :string

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

  # Like site_only_observations except for users. Used in places like /people
  preference :site_only_users, :boolean, :default => false

  # iOS app ID. Used to display header notice about app in mobile views
  preference :ios_app_id, :string

  # If you'd prefer the default taxon ranges to come from a particular Source, set the source ID here
  # taxon_range_source_id: 7538
  belongs_to :taxon_range_source, :class_name => "Source"

  # google_analytics, http://www.google.com/analytics/
  preference :google_analytics_tracker_id, :string

  # google webmaster tools, http://www.google.com/webmasters/tools/
  preference :google_webmaster_verification, :string

  # uBio is a taxonomic information provider. http://www.ubio.org
  preference :ubio_key, :string

  # Yahoo Developers Network API provides place info
  # https://developer.apps.yahoo.com/wsregapp/
  preference :yahoo_developers_network_app_id, :string

  # Configure taxon description callbacks. taxa/show will try to show
  # species descriptions from these sources in this order, trying the next
  # if one fails. You can see all the available describers in
  # lib/taxon_describers/lib/taxon_describers
  preference :taxon_describers, :string

  # facebook
  preference :facebook_app_id, :string
  preference :facebook_app_secret, :string
  # facebook user IDs of people who can admin pages on the site
  preference :facebook_admin_ids, :string # array
  preference :facebook_namespace, :string # your facebook app's namespace, used for open graph tags

  # twitter
  preference :twitter_key, :string
  preference :twitter_secret, :string
  preference :twitter_url, :string
  preference :twitter_username, :string

  preference :blog_url, :string

  preference :cloudmade_key, :string

  preference :bing_key, :string

  # flickr, http://www.flickr.com/services/api/keys/apply/
  preference :flickr_key, :string
  preference :flickr_shared_secret, :string

  # soundcloud, http://soundcloud.com/you/apps/new
  preference :soundcloud_client_id, :string
  preference :soundcloud_secret, :string

  # Ratatosk is an internal library for looking up external taxonomy info.
  # By default it uses all registered name providers, but you can
  # configure it here to use a subset
  # ratatosk:
  preference :name_providers, :string #: [col, ubio]

  preference :natureserve_key, :string
  preference :custom_logo, :text
  preference :custom_footer, :text
  preference :custom_secondary_footer, :text
  preference :custom_email_footer_leftside, :text
  preference :custom_email_footer_rightside, :text

  # Whether this site prefers https
  preference :ssl, :boolean

  def to_s
    "<Site #{id} #{url}>"
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
    url = logo_square.url
    url = URI.join(CONFIG.site_url, url).to_s unless url =~ /^http/
    url
  end

  def home_page_wiki_path_by_locale( locale )
    return nil if preferred_home_page_wiki_path_by_locale.blank?
    paths = JSON.parse( preferred_home_page_wiki_path_by_locale ) rescue {}
    unless path = paths[ locale.to_s ]
      path = paths[ locale.to_s.split("-")[0] ]
    end
    path
  end
end
