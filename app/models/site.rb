# frozen_string_literal: true

class Site < ApplicationRecord
  include HasJournal

  has_many :observations, inverse_of: :site
  has_many :users, inverse_of: :site
  has_many :site_admins, inverse_of: :site
  has_many :posts, as: :parent, dependent: :destroy
  has_many :site_featured_projects, dependent: :destroy
  has_and_belongs_to_many :announcements

  scope :live, -> { where( draft: false ) }
  scope :drafts, -> { where( draft: true ) }

  # shortened version of the name
  preference :site_name_short, :string

  # Email addresses
  preference :email_noreply, :string, default: CONFIG.noreply_email
  preference :email_help, :string, default: CONFIG.help_email

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

  preference :locale, :string

  # default bounds for most maps, including /observations/new and the home page. Defaults to the whole world
  preference :geo_swlat, :string
  preference :geo_swlng, :string
  preference :geo_nelat, :string
  preference :geo_nelng, :string

  preference :map_about_url, :string
  preference :legacy_rest_auth_key, :string

  # default place ID for place filters. Presently only used on /places, but use may be expanded
  belongs_to :place, inverse_of: :sites

  has_many :places_sites, dependent: :destroy
  has_many :export_places_sites,
    -> { where( scope: PlacesSite::EXPORTS ) },
    class_name: "PlacesSite"
  has_many :export_places,
    through: :export_places_sites,
    source: "place"
  accepts_nested_attributes_for :export_places_sites, allow_destroy: true

  # header logo, should be at least 118x22
  if CONFIG.usingS3
    has_attached_file :logo,
      storage: :s3,
      s3_credentials: "#{Rails.root}/config/s3.yml",
      s3_protocol: CONFIG.s3_protocol || "https",
      s3_host_alias: CONFIG.s3_host || CONFIG.s3_bucket,
      s3_region: CONFIG.s3_region,
      bucket: CONFIG.s3_bucket,
      path: "sites/:id-logo.:extension",
      url: ":s3_alias_url",
      default_url: "logo-small.gif"
    invalidate_cloudfront_caches :logo, "sites/:id-logo.*"
  else
    has_attached_file :logo,
      path: ":rails_root/public/attachments/sites/:id-logo.:extension",
      url: "/attachments/sites/:id-logo.:extension",
      default_url: "logo-small.gif"
  end
  validates_attachment_content_type :logo, content_type: [/jpe?g/i, /png/i, /gif/i, /octet-stream/, /svg/],
    message: "must be JPG, PNG, SVG, or GIF"
  validate do | site |
    if site.errors.none? &&
        site.logo.queued_for_write[:original] &&
        site.logo.content_type.to_s !~ /svg/i
      dimensions = Paperclip::Geometry.from_file( site.logo.queued_for_write[:original].path )
      if dimensions.height > 70
        errors.add( :logo, "cannot have a height larger than 70px" )
      end
    end
    true
  end

  # large square branding image that appears on pages like /login. Should be 300 px wide and about that tall
  if CONFIG.usingS3
    has_attached_file :logo_square,
      storage: :s3,
      s3_credentials: "#{Rails.root}/config/s3.yml",
      s3_protocol: CONFIG.s3_protocol || "https",
      s3_host_alias: CONFIG.s3_host || CONFIG.s3_bucket,
      s3_region: CONFIG.s3_region,
      bucket: CONFIG.s3_bucket,
      path: "sites/:id-logo_square.:extension",
      url: ":s3_alias_url",
      default_url: "bird.png",
      styles: {
        original: { geometry: "300x300>#" }
      }
    invalidate_cloudfront_caches :logo_square, "sites/:id-logo_square.*"
  else
    has_attached_file :logo_square,
      path: ":rails_root/public/attachments/sites/:id-logo_square.:extension",
      url: "/attachments/sites/:id-logo_square.:extension",
      default_url: "bird.png",
      styles: {
        original: { geometry: "300x300>#" }
      }
  end
  validates_attachment_content_type :logo_square, content_type: [/jpe?g/i, /png/i, /gif/i, /octet-stream/],
    message: "must be JPG, PNG, or GIF"

  if CONFIG.usingS3
    has_attached_file :logo_email_banner,
      storage: :s3,
      s3_credentials: "#{Rails.root}/config/s3.yml",
      s3_protocol: CONFIG.s3_protocol || "https",
      s3_region: CONFIG.s3_region,
      s3_host_alias: CONFIG.s3_host || CONFIG.s3_bucket,
      bucket: CONFIG.s3_bucket,
      path: "sites/:id-logo_email_banner.:extension",
      url: ":s3_alias_url",
      default_url: "inat_email_banner.png",
      styles: {
        original: { geometry: "600x600>" }
      }
    invalidate_cloudfront_caches :logo_email_banner, "sites/:id-logo_email_banner.*"
  else
    has_attached_file :logo_email_banner,
      path: ":rails_root/public/attachments/sites/:id-logo_email_banner.:extension",
      url: "/attachments/sites/:id-logo_email_banner.:extension",
      default_url: "inat_email_banner.png",
      styles: {
        original: { geometry: "600x600>" }
      }
  end
  validates_attachment_content_type :logo_email_banner,
    content_type: [/jpe?g/i, /png/i, /gif/i, /octet-stream/],
    message: "must be JPG, PNG, or GIF"

  if CONFIG.usingS3
    has_attached_file :logo_blog,
      storage: :s3,
      s3_credentials: "#{Rails.root}/config/s3.yml",
      s3_protocol: CONFIG.s3_protocol || "https",
      s3_host_alias: CONFIG.s3_host || CONFIG.s3_bucket,
      s3_region: CONFIG.s3_region,
      bucket: CONFIG.s3_bucket,
      path: "sites/:id-logo_blog.:extension",
      url: ":s3_alias_url"
    invalidate_cloudfront_caches :logo, "sites/:id-logo_blog.*"
  else
    has_attached_file :logo_blog,
      path: ":rails_root/public/attachments/sites/:id-logo_blog.:extension",
      url: "/attachments/sites/:id-logo_blog.:extension"
  end
  validates_attachment_content_type :logo_blog, content_type: [/jpe?g/i, /png/i, /gif/i, /octet-stream/, /svg/],
    message: "must be JPG, PNG, SVG, or GIF"
  validate do | site |
    if site.errors.none? &&
        site.logo_blog.queued_for_write[:original] &&
        site.logo_blog.content_type.to_s !~ /svg/i
      dimensions = Paperclip::Geometry.from_file( site.logo_blog.queued_for_write[:original].path )
      if dimensions.height > 110 || dimensions.width > 110
        errors.add( :logo_blog, "cannot have a height larger than 110x110px" )
      end
    end
    true
  end

  if CONFIG.usingS3
    has_attached_file :favicon,
      storage: :s3,
      s3_credentials: "#{Rails.root}/config/s3.yml",
      s3_protocol: CONFIG.s3_protocol || "https",
      s3_region: CONFIG.s3_region,
      s3_host_alias: CONFIG.s3_host || CONFIG.s3_bucket,
      bucket: CONFIG.s3_bucket,
      path: "sites/:id-favicon.:extension",
      url: ":s3_alias_url",
      default_url: "favicon.png",
      styles: {
        original: { geometry: "64x64>#" }
      }
    invalidate_cloudfront_caches :favicon, "sites/:id-favicon.*"
  else
    has_attached_file :favicon,
      path: ":rails_root/public/attachments/sites/:id-favicon.:extension",
      url: "/attachments/sites/:id-favicon.:extension",
      default_url: "favicon.png",
      styles: {
        original: { geometry: "64x64>#" }
      }
  end
  validates_attachment_content_type :favicon,
    content_type: [/png/i, /gif/i, "image/x-icon", "image/vnd.microsoft.icon"],
    message: "must be PNG, GIF, or ICO"

  if CONFIG.usingS3
    has_attached_file :shareable_image,
      storage: :s3,
      s3_credentials: "#{Rails.root}/config/s3.yml",
      s3_protocol: CONFIG.s3_protocol || "https",
      s3_region: CONFIG.s3_region,
      s3_host_alias: CONFIG.s3_host || CONFIG.s3_bucket,
      bucket: CONFIG.s3_bucket,
      path: "sites/:id-shareable_image.:extension",
      url: ":s3_alias_url"
    invalidate_cloudfront_caches :shareable_image, "sites/:id-shareable_image.*"
  else
    has_attached_file :shareable_image,
      path: ":rails_root/public/attachments/sites/:id-shareable_image.:extension",
      url: "/attachments/sites/:id-shareable_image.:extension"
  end
  validates_attachment_content_type :shareable_image,
    content_type: [/jpe?g/i, /png/i, /gif/i, /octet-stream/],
    message: "must be JPG, PNG, or GIF"

  # CSS file to override default styles
  if CONFIG.usingS3
    has_attached_file :stylesheet,
      storage: :s3,
      s3_credentials: "#{Rails.root}/config/s3.yml",
      s3_protocol: CONFIG.s3_protocol || "https",
      s3_region: CONFIG.s3_region,
      s3_host_alias: CONFIG.s3_host || CONFIG.s3_bucket,
      bucket: CONFIG.s3_bucket,
      path: "sites/:id-stylesheet.css",
      url: ":s3_alias_url"
    invalidate_cloudfront_caches :stylesheet, "sites/:id-stylesheet.css"
  else
    has_attached_file :stylesheet,
      path: ":rails_root/public/attachments/sites/:id-stylesheet.css",
      url: "/attachments/sites/:id-stylesheet.css"
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
  preference :help_url, :string, default: "/pages/help"

  # URL where visitors can get started using the site
  preference :getting_started_url, :string, default: "/pages/getting+started"

  # URL where press can learn more about the site and get assets
  preference :press_url, :string

  preference :feedback_url, :string
  preference :discourse_url, :string
  preference :discourse_category, :string
  preference :terms_url, :string, default: "/pages/terms"
  preference :privacy_url, :string, default: "/pages/privacy"
  preference :developers_url, :string, default: "/pages/developers"
  preference :community_guidelines_url, :string, default: "/pages/community+guidelines"
  preference :jobs_url, :string, default: "/pages/jobs"
  preference :twitter_url, :string
  preference :iphone_app_url, :string
  preference :android_app_url, :string
  preference :facebook_url, :string
  preference :twitter_url, :string
  preference :instagram_url, :string
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
  OBSERVATIONS_FILTERS = %w(site place bounding_box).freeze
  OBSERVATIONS_FILTERS.each do | f |
    const_set "OBSERVATIONS_FILTERS_#{f.upcase.gsub( /-/, '_' )}", f
  end
  preference :site_observations_filter, :string, default: OBSERVATIONS_FILTERS_PLACE

  # Used in places like /people
  preference :site_only_users, :boolean, default: false

  # iOS app ID. Used to display header notice about app in mobile views
  preference :ios_app_id, :string
  preference :ios_app_webcredentials, :string

  # If you'd prefer the default taxon ranges to come from a particular Source, set the source ID here
  # taxon_range_source_id: 7538
  belongs_to :taxon_range_source, class_name: "Source", foreign_key: "source_id"

  # google_analytics, http://www.google.com/analytics/
  preference :google_analytics_tracker_id, :string

  # google webmaster tools, http://www.google.com/webmasters/tools/
  preference :google_webmaster_verification, :string
  preference :google_webmaster_dns_verification, :string
  preference :google_webmaster_dns_verified, :boolean

  # google recaptcha, https://www.google.com/recaptcha
  preference :google_recaptcha_key, :string
  preference :google_recaptcha_secret, :string

  # We have a limited number of callback URLs we're allowed on twitter, and
  # we've used them all
  preference :twitter_sign_in, :boolean, default: false

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

  preference :affiliated_organizations, :text

  STAFF_ONLY_PREFERENCES = [
    :google_webmaster_dns_verification,
    :google_webmaster_dns_verified,
    :twitter_sign_in
  ].freeze

  after_save :refresh_default_site

  def self.default( options = {} )
    if options[:refresh]
      Rails.cache.delete( "sites_default" )
    end
    if ( cached = Rails.cache.read( "sites_default" ) )
      return cached
    end

    unless site = Site.includes( :stored_preferences ).first
      site = Site.create!( name: "iNaturalist", url: "http://localhost:3000" )
    end

    Rails.cache.fetch( "sites_default" ) do
      site
    end
  end

  def to_s
    "<Site #{id} #{name} #{url}>"
  end

  # contact element for a DarwinCore Archive (DwC-A). This is supposed to be the
  # person data consumers can contact with questions about the archive
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

  # creator element for use in a DarwinCore Archive (DwC-A)
  # According to the schema, "The creator is the person who created the
  # resource (not necessarily the author of this metadata about the resource).
  # This is the person or institution to contact with questions about the use,
  # interpretation of a dataset." Since no collection of iNat records was
  # created by a single person, we are using the name of the site itself as the
  # creator
  def dwc_creator
    {
      organization: name,
      last_name: "#{name} contributors"
    }
  end

  # rubocop:disable Style/OptionalBooleanParameter
  def respond_to?( method, include_all = false )
    preferences.keys.include?( method.to_s ) ? true : super
  end
  # rubocop:enable Style/OptionalBooleanParameter

  def respond_to_missing?( name, include_private )
    preferences.keys.include?( name ) || super( name, include_private )
  end

  def method_missing( method, *args, &block )
    preferences.keys.include?( method.to_s ) ? preferences[method.to_s] : super
  end

  def editable_by?( user )
    user && ( user.is_admin? || user.is_site_admin_of?( self ) )
  end

  def icon_url
    return nil unless logo_square.file?

    logo_square.url
  end

  def home_page_wiki_path_by_locale( locale )
    return nil if preferred_home_page_wiki_path_by_locale.blank?

    paths = begin
      JSON.parse( preferred_home_page_wiki_path_by_locale )
    rescue StandardError
      {}
    end
    unless ( path = paths[locale.to_s] )
      path = paths[locale.to_s.split( "-" )[0]]
    end
    path
  end

  def coordinate_systems
    return if coordinate_systems_json.blank?

    systems = begin
      JSON.parse( coordinate_systems_json )
    rescue StandardError
      {}
    end
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

  def using_recaptcha?
    !google_recaptcha_key.blank? && !google_recaptcha_secret.blank?
  end

  def refresh_default_site
    return unless id == Site.default&.id

    Site.default( refresh: true )
  end

  def short_url
    url.sub( %r{https?://}, "" ).sub( %r{/$}, "" )
  end

  # We can't use OAuth to authenticate a user with Google unless our OAuth
  # authentication page has been approved by Google with the domain that is
  # showing this button, and in order to do so, we need that domain to be
  # verified under our Google account, and to do that we need the owner of the
  # domain to add a DNS record (see the site settings page for the site in
  # question)
  #
  # So, in cases where we're trying to show a button to link a Google account
  # AND the site does not use an inaturalist.org subdomain AND the site's domain
  # has not been verified, we cannot show the button.
  def google_oauth_allowed?
    default_site_domain = URI.parse( Site.default.url ).host.to_s[/\.(.+)$/, 1]
    return true if default_site_domain.blank?

    prefers_google_webmaster_dns_verified? || URI.parse( url.to_s ).host.to_s.include?( default_site_domain )
  end

  # Path where the site data export file *should* be. Actual generation happens
  # via the export_site_data.rb script and the SiteDataExporter class
  def export_path
    private_page_cache_path( File.join(
      "export_site_data",
      "#{SiteDataExporter.basename_for_site( self )}.zip"
    ) )
  end

  def login_featured_observations
    Rails.cache.fetch( "Site::#{id}::login_featured_observations", expires_in: 1.hour ) do
      es_query = {
        has: ["photos"],
        per_page: 100,
        order_by: "votes",
        order: "desc",
        place_id: try(:place_id).blank? ? nil : place_id,
        projects: ["log-in-photos"]
      }
      observations = Observation.elastic_query( es_query ).to_a
      if observations.blank?
        es_query.delete(:projects)
        observations = Observation.elastic_query( es_query ).to_a
      end
      if observations.blank?
        es_query.delete(:place_id)
        observations = Observation.elastic_query( es_query ).to_a
      end
      Observation.preload_associations( observations, [:user, {
        observations_places: :place,
        observation_photos: {
          photo: [:flags, :file_prefix, :file_extension]
        },
        taxon: :taxon_names,
      }] )
      if es_query[:projects].blank?
        observations = observations.select do |o|
          photo = o.observation_photos.sort_by{ |op| op.position || op.id }.first.photo
        end
      end
      observations
    end
  end
end
