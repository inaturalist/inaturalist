class User < ActiveRecord::Base
  include ActsAsSpammable::User
  include ActsAsElasticModel

  acts_as_voter
  acts_as_spammable fields: [ :description ],
                    comment_type: "signup"

  # If the user has this role, has_role? will always return true
  JEDI_MASTER_ROLE = 'admin'
  
  devise :database_authenticatable, :registerable, :suspendable,
         :recoverable, :rememberable, :confirmable, :validatable, 
         :encryptable, :encryptor => :restful_authentication_sha1
  handle_asynchronously :send_devise_notification
  
  # set user.skip_email_validation = true if you want to, um, skip email validation before creating+saving
  attr_accessor :skip_email_validation
  attr_accessor :skip_registration_email
  
  # licensing extras
  attr_accessor   :make_observation_licenses_same
  attr_accessor   :make_photo_licenses_same
  attr_accessor   :make_sound_licenses_same

  attr_accessor :html
  attr_accessor :pi_consent

  # Email notification preferences
  preference :comment_email_notification, :boolean, default: true
  preference :identification_email_notification, :boolean, default: true
  preference :message_email_notification, :boolean, default: true
  preference :no_email, :boolean, default: false
  preference :project_invitation_email_notification, :boolean, default: true
  preference :mention_email_notification, :boolean, default: true
  preference :project_journal_post_email_notification, :boolean, default: true
  preference :project_curator_change_email_notification, :boolean, default: true
  preference :project_added_your_observation_email_notification, :boolean, default: true
  preference :taxon_change_email_notification, :boolean, default: true
  preference :user_observation_email_notification, :boolean, default: true
  preference :taxon_or_place_observation_email_notification, :boolean, default: true

  preference :lists_by_login_sort, :string, :default => "id"
  preference :lists_by_login_order, :string, :default => "asc"
  preference :per_page, :integer, :default => 30
  preference :gbif_sharing, :boolean, :default => true
  preference :observation_license, :string
  preference :photo_license, :string
  preference :sound_license, :string
  preference :automatic_taxonomic_changes, :boolean, :default => true
  preference :receive_mentions, :boolean, :default => true
  preference :observations_view, :string
  preference :observations_search_subview, :string
  preference :observations_search_map_type, :string, default: "terrain"
  preference :community_taxa, :boolean, :default => true
  PREFERRED_OBSERVATION_FIELDS_BY_ANYONE = "anyone"
  PREFERRED_OBSERVATION_FIELDS_BY_CURATORS = "curators"
  PREFERRED_OBSERVATION_FIELDS_BY_OBSERVER = "observer"
  preference :observation_fields_by, :string, :default => PREFERRED_OBSERVATION_FIELDS_BY_ANYONE
  PROJECT_ADDITION_BY_ANY = "any"
  PROJECT_ADDITION_BY_JOINED = "joined"
  PROJECT_ADDITION_BY_NONE = "none"
  preference :project_addition_by, :string, default: PROJECT_ADDITION_BY_ANY
  preference :location_details, :boolean, default: false
  preference :redundant_identification_notifications, :boolean, default: true
  preference :skip_coarer_id_modal, default: false
  preference :hide_observe_onboarding, default: false
  preference :hide_follow_onboarding, default: false
  preference :hide_activity_onboarding, default: false
  preference :hide_getting_started_onboarding, default: false
  preference :hide_updates_by_you_onboarding, default: false
  preference :hide_comments_onboarding, default: false
  preference :hide_following_onboarding, default: false
  preference :taxon_page_place_id, :integer
  preference :hide_obs_show_annotations, default: false
  preference :hide_obs_show_projects, default: false
  preference :hide_obs_show_tags, default: false
  preference :hide_obs_show_observation_fields, default: false
  preference :hide_obs_show_identifiers, default: false
  preference :hide_obs_show_copyright, default: false
  preference :hide_obs_show_quality_metrics, default: false
  preference :hide_obs_show_expanded_cid, default: true
  preference :common_names, :boolean, default: true 
  preference :scientific_name_first, :boolean, default: false
  preference :no_place, :boolean, default: false
  preference :medialess_obs_maps, :boolean, default: false
  preference :coordinate_interpolation_protection, default: false
  preference :coordinate_interpolation_protection_test, default: false
  preference :forum_topics_on_dashboard, :boolean, default: true
  preference :monthly_supporter_badge, :boolean, default: false
  preference :map_tile_test, :boolean, default: false
  preference :no_site, :boolean, default: false
  preference :no_tracking, :boolean, default: false
  
  NOTIFICATION_PREFERENCES = %w(
    comment_email_notification
    identification_email_notification 
    mention_email_notification
    message_email_notification
    project_journal_post_email_notification
    project_added_your_observation_email_notification
    project_curator_change_email_notification
    taxon_change_email_notification
    user_observation_email_notification
    taxon_or_place_observation_email_notification
  )
  
  belongs_to :life_list, :dependent => :destroy
  has_many  :provider_authorizations, :dependent => :delete_all
  has_one  :flickr_identity, :dependent => :delete
  # has_one  :picasa_identity, :dependent => :delete
  has_one  :soundcloud_identity, :dependent => :delete
  has_many :observations, :dependent => :destroy
  has_many :deleted_observations
  has_many :deleted_photos
  has_many :deleted_sounds
  has_many :friendships, dependent: :destroy

  def followees
    User.where( "friendships.user_id = ?", id ).
      joins( "JOIN friendships ON friendships.friend_id = users.id" ).
      where( "friendships.following" ).
      where( "users.suspended_at IS NULL" )
  end

  def followers
    User.where( "friendships.friend_id = ?", id ).
      joins( "JOIN friendships ON friendships.user_id = users.id" ).
      where( "friendships.following" ).
      where( "users.suspended_at IS NULL" )
  end

  has_many :lists, :dependent => :destroy
  has_many :life_lists
  has_many :identifications, :dependent => :destroy
  has_many :identifications_for_others,
    -> { where("identifications.user_id != observations.user_id AND identifications.current = true").
         joins(:observation) }, :class_name => "Identification"
  has_many :photos, :dependent => :destroy
  has_many :sounds, dependent: :destroy
  has_many :posts #, :dependent => :destroy
  has_many :journal_posts, :class_name => "Post", :as => :parent, :dependent => :destroy
  has_many :trips, -> { where("posts.type = 'Trip'") }, :class_name => "Post", :foreign_key => "user_id"
  has_many :taxon_links, :dependent => :nullify
  has_many :comments, :dependent => :destroy
  has_many :projects
  has_many :project_users, :dependent => :destroy
  has_many :project_user_invitations, :dependent => :nullify
  has_many :project_user_invitations_received, :dependent => :delete_all, :class_name => "ProjectUserInvitation"
  has_many :listed_taxa, :dependent => :nullify
  has_many :invites, :dependent => :nullify
  has_many :quality_metrics, :dependent => :destroy
  has_many :sources, :dependent => :nullify
  has_many :places, :dependent => :nullify
  has_many :messages, :dependent => :destroy
  has_many :delivered_messages, -> { where("messages.from_user_id != messages.user_id") }, :class_name => "Message", :foreign_key => "from_user_id"
  has_many :guides, :dependent => :destroy, :inverse_of => :user
  has_many :observation_fields, :dependent => :nullify, :inverse_of => :user
  has_many :observation_field_values, :dependent => :nullify, :inverse_of => :user
  has_many :updated_observation_field_values, :dependent => :nullify, :inverse_of => :updater, :foreign_key => "updater_id", :class_name => "ObservationFieldValue"
  has_many :guide_users, :inverse_of => :user, :dependent => :delete_all
  has_many :editing_guides, :through => :guide_users, :source => :guide
  has_many :created_guide_sections, :class_name => "GuideSection", :foreign_key => "creator_id", :inverse_of => :creator, :dependent => :nullify
  has_many :updated_guide_sections, :class_name => "GuideSection", :foreign_key => "updater_id", :inverse_of => :updater, :dependent => :nullify
  has_many :atlases, :inverse_of => :user, :dependent => :nullify
  has_many :user_blocks, inverse_of: :user, dependent: :destroy
  has_many :user_blocks_as_blocked_user, class_name: "UserBlock", foreign_key: "blocked_user_id", inverse_of: :blocked_user, dependent: :destroy
  has_many :user_mutes, inverse_of: :user, dependent: :destroy
  has_many :user_mutes_as_muted_user, class_name: "UserMute", foreign_key: "muted_user_id", inverse_of: :muted_user, dependent: :destroy
  has_many :taxon_curators, inverse_of: :user, dependent: :destroy
  has_many :taxon_changes, inverse_of: :user
  has_many :taxon_framework_relationships
  has_many :annotations, dependent: :destroy
  has_many :saved_locations, inverse_of: :user, dependent: :destroy
  has_many :user_privileges, inverse_of: :user, dependent: :delete_all
  has_one :user_parent, dependent: :destroy, inverse_of: :user
  has_many :parentages, class_name: "UserParent", foreign_key: "parent_user_id", inverse_of: :parent_user
  has_many :moderator_actions, inverse_of: :user
  
  file_options = {
    processors: [:deanimator],
    styles: {
      original: "2048x2048>",
      large: "500x500>",
      medium: "300x300>",
      thumb: "48x48#",
      mini: "16x16#"
    }
  }

  if CONFIG.usingS3
    has_attached_file :icon, file_options.merge(
      storage: :s3,
      s3_credentials: "#{Rails.root}/config/s3.yml",
      s3_protocol: CONFIG.s3_protocol || "https",
      s3_host_alias: CONFIG.s3_host || CONFIG.s3_bucket,
      s3_region: CONFIG.s3_region,
      bucket: CONFIG.s3_bucket,
      path: "/attachments/users/icons/:id/:style.:icon_type_extension",
      default_url: ":root_url/attachment_defaults/users/icons/defaults/:style.png",
      url: ":s3_alias_url"
    )
    invalidate_cloudfront_caches :icon, "attachments/users/icons/:id/*"
  else
    has_attached_file :icon, file_options.merge(
      path: ":rails_root/public/attachments/:class/:attachment/:id-:style.:icon_type_extension",
      url: "/attachments/:class/:attachment/:id-:style.:icon_type_extension",
      default_url: "/attachment_defaults/:class/:attachment/defaults/:style.png"
    )
  end

  # Roles
  has_and_belongs_to_many :roles, -> { uniq }
  belongs_to :curator_sponsor, class_name: "User"
  belongs_to :suspended_by_user, class_name: "User"
  
  has_subscribers
  has_many :subscriptions, :dependent => :delete_all
  has_many :flow_tasks
  has_many :project_observations, dependent: :nullify 
  belongs_to :site, :inverse_of => :users
  has_many :site_admins, inverse_of: :user
  belongs_to :place, :inverse_of => :users
  belongs_to :search_place, inverse_of: :search_users, class_name: "Place"

  before_validation :download_remote_icon, :if => :icon_url_provided?
  before_validation :strip_name, :strip_login
  before_save :set_time_zone
  before_save :whitelist_licenses
  before_save :get_lat_lon_from_ip_if_last_ip_changed
  before_save :check_suspended_by_user
  before_save :set_pi_consent_at
  before_save :set_locale
  after_save :update_observation_licenses
  after_save :update_photo_licenses
  after_save :update_sound_licenses
  after_save :update_observation_sites_later
  after_save :destroy_messages_by_suspended_user
  after_save :revoke_access_tokens_by_suspended_user
  after_save :restore_access_tokens_by_suspended_user
  after_update :set_observations_taxa_if_pref_changed
  after_update :reassess_coordinate_obscuration_if_pref_changed
  after_update :update_photo_properties
  after_update :update_life_list
  after_create :create_default_life_list
  after_create :set_uri
  after_destroy :create_deleted_user
  after_destroy :remove_oauth_access_tokens
  after_destroy :destroy_project_rules
  after_destroy :reindex_faved_observations_after_destroy_later

  validates_presence_of :icon_url, :if => :icon_url_provided?, :message => 'is invalid or inaccessible'
  validates_attachment_content_type :icon, :content_type => [/jpe?g/i, /png/i, /gif/i],
    :message => "must be JPG, PNG, or GIF"

  validates_presence_of     :login
  
  MIN_LOGIN_SIZE = 3
  MAX_LOGIN_SIZE = 40

  # Regexes from restful_authentication
  LOGIN_PATTERN     = "[A-Za-z][\\\w\\\-_]+"
  login_regex       = /\A#{ LOGIN_PATTERN }\z/                          # ASCII, strict
  email_name_regex  = '[\w\.%\+\-]+'.freeze
  domain_head_regex = '(?:[A-Z0-9\-]+\.)+'.freeze
  domain_tld_regex  = '(?:[A-Z]+)'.freeze
  email_regex       = /\A#{email_name_regex}@#{domain_head_regex}#{domain_tld_regex}\z/i
  
  validates_length_of       :login,     within: MIN_LOGIN_SIZE..MAX_LOGIN_SIZE
  validates_uniqueness_of   :login
  validates_format_of       :login,     with: login_regex, message: :must_begin_with_a_letter
  validates_exclusion_of    :login,     in: %w(password new edit create update delete destroy)

  validates_exclusion_of    :password,     in: %w(password)

  validates_length_of       :name,      maximum: 100, allow_blank: true

  validates_format_of       :email,     with: email_regex, message: :must_look_like_an_email_address, allow_blank: true
  validates_length_of       :email,     within: 6..100, allow_blank: true
  validates_length_of       :time_zone, minimum: 3, allow_nil: true
  validate :validate_email_pattern, on: :create
  validate :validate_email_domain_exists, on: :create
  
  scope :order_by, Proc.new { |sort_by, sort_dir|
    sort_dir ||= 'DESC'
    order("? ?", sort_by, sort_dir)
  }
  scope :curators, -> { joins(:roles).where("roles.name IN ('curator', 'admin')") }
  scope :admins, -> { joins(:roles).where("roles.name = 'admin'") }
  scope :active, -> { where("suspended_at IS NULL") }

  def validate_email_pattern
    return if CONFIG.banned_emails.blank?
    return if self.email.blank?
    failed = false
    CONFIG.banned_emails.each do |banned_suffix|
      next if failed
      if self.email.match(/#{banned_suffix}$/)
        errors.add( :email, :domain_is_not_supported )
        failed = true
      end
    end
  end

  # As noted at
  # https://stackoverflow.com/questions/39721917/check-if-email-domain-is-valid,
  # this approach is probably going to have some false positives... but probably
  # not many
  def validate_email_domain_exists
    return true if Rails.env.test? && CONFIG.user_email_domain_exists_validation != :enabled
    return true if self.email.blank?
    domain = email.split( "@" )[1].strip
    dns_response = begin
      r = nil
      Timeout::timeout( 5 ) do
        Resolv::DNS.open do |dns|
          r = dns.getresources( domain, Resolv::DNS::Resource::IN::MX )
        end
      end
      r
    rescue Timeout::Error
      begin
        r = nil
        Timeout::timeout( 5 ) do
          Resolv::DNS.open do |dns|
            r = dns.getresources( domain, Resolv::DNS::Resource::IN::A )
          end
        end
        r
      rescue Timeout::Error
        r = nil
      end
    end
    if dns_response.blank?
      errors.add( :email, :domain_is_not_supported )
    end
    true
  end

  # only validate_presence_of email if user hasn't auth'd via a 3rd-party provider
  # you can also force skipping email validation by setting u.skip_email_validation=true before you save
  # (this option is necessary because the User is created before the associated ProviderAuthorization)
  # This is not a normal validation b/c email validation happens in Devise, which looks for this method
  def email_required?
    !(skip_email_validation || provider_authorizations.count > 0)
  end
  
  def icon_url_provided?
    !self.icon.present? && !self.icon_url.blank?
  end

  def user_icon_url
    return nil if icon.blank?
    "#{FakeView.asset_url(icon.url(:thumb))}".gsub(/([^\:])\/\//, '\\1/')
  end
  
  def medium_user_icon_url
    return nil if icon.blank?
    "#{FakeView.asset_url(icon.url(:medium))}".gsub(/([^\:])\/\//, '\\1/')
  end
  
  def original_user_icon_url
    return nil if icon.blank?
    "#{FakeView.asset_url(icon.url)}".gsub(/([^\:])\/\//, '\\1/')
  end

  def active?
    !suspended?
  end

  # This is a dangerous override in that it doesn't call super, thereby
  # ignoring the results of all the devise modules like confirmable. We do
  # this b/c we want all users to be able to sign in, even if unconfirmed, but
  # not if suspended.
  def active_for_authentication?
    active? && ( birthday.blank? || birthday < 13.years.ago || !UserParent.where( "user_id = ? AND donorbox_donor_id IS NULL", id ).exists? )
  end

  def download_remote_icon
    io = open(URI.parse(self.icon_url))
    Timeout::timeout(10) do
      self.icon = (io.base_uri.path.split('/').last.blank? ? nil : io)
    end
    true
  rescue => e # catch url errors with validations instead of exceptions (Errno::ENOENT, OpenURI::HTTPError, etc...)
    Rails.logger.error "[ERROR #{Time.now}] Failed to download_remote_icon for #{id}: #{e}"
    true
  end

  def strip_name
    return true if name.blank?
    self.name = FakeView.strip_tags( name ).to_s
    self.name = name.gsub(/[\s\n\t]+/, ' ').strip
    true
  end

  def strip_login
    return true if login.blank?
    self.login = login.strip
    true
  end
  
  def whitelist_licenses
    self.preferred_observation_license = Shared::LicenseModule.normalize_license_code( preferred_observation_license )
    self.preferred_photo_license = Shared::LicenseModule.normalize_license_code( preferred_photo_license )
    self.preferred_sound_license = Shared::LicenseModule.normalize_license_code( preferred_sound_license )
    
    unless preferred_observation_license.blank? || Observation::LICENSE_CODES.include?( preferred_observation_license )
      self.preferred_observation_license = nil
    end
    
    unless preferred_photo_license.blank? || Observation::LICENSE_CODES.include?( preferred_photo_license )
      self.preferred_photo_license = nil
    end

    unless preferred_sound_license.blank? || Observation::LICENSE_CODES.include?( preferred_sound_license )
      self.preferred_sound_license = nil
    end

    true
  end

  # add a provider_authorization to this user.  
  # auth_info is the omniauth info from rack.
  def add_provider_auth(auth_info)
    pa = self.provider_authorizations.build
    pa.assign_auth_info(auth_info)
    pa.auth_info = auth_info
    pa.save
    pa
  end

  # test to see if this user has authorized with the given provider
  # argument is one of: 'facebook', 'twitter', 'google', 'yahoo'
  # returns either nil or the appropriate ProviderAuthorization
  def has_provider_auth(provider)
    provider = provider.downcase
    provider_authorizations.detect do |p| 
      p.provider_name.match(provider) || p.provider_uid.match(provider)
    end
  end

  def login=(value)
    write_attribute :login, (value ? value.to_s.downcase : nil)
  end

  def email=(value)
    write_attribute :email, (value ? value.to_s.downcase : nil)
  end
  
  # Role related methods
  
  # Checks if a user has a role; returns true if they don't but
  # are admin.  Admins are supreme beings
  def has_role?(role)
    role_list ||= roles.map(&:name)
    role_list.include?(role.to_s) || role_list.include?(User::JEDI_MASTER_ROLE)
  end

  # Everything below here was added for iNaturalist
  
  # TODO: named_scope
  def recent_observations(num = 5)
    observations.order("created_at DESC").limit(num)
  end

  # TODO: named_scope  
  def friends_observations(limit = 5)
    obs = []
    friends.each do |friend|
      obs << friend.observations.order("created_at DESC").limit(limit)
    end
    obs.flatten
  end
  
  
  # TODO: named_scope / roles plugin
  def is_curator?
    has_role?(:curator)
  end
  
  def is_admin?
    has_role?(:admin)
  end
  alias :admin? :is_admin?

  def is_site_admin_of?( site )
    return false unless site && site.is_a?( Site )
    !!site_admins.detect{ |sa| sa.site_id == site.id }
  end

  def to_s
    "<User #{self.id}: #{self.login}>"
  end
  
  def friends_with?(user)
    friends.exists?(user)
  end
  
  def picasa_client
    return nil unless (pa = has_provider_auth('google'))
    @picasa_client ||= Picasa.new(pa.token)
  end

  # returns a koala object to make (authenticated) facebook api calls
  # e.g. @facebook_api.get_object('me')
  # see koala docs for available methods: https://github.com/arsduo/koala
  def facebook_api
    return nil unless facebook_identity
    @facebook_api ||= Koala::Facebook::API.new(facebook_identity.token)
  end
  
  # returns nil or the facebook ProviderAuthorization
  def facebook_identity
    @facebook_identity ||= has_provider_auth('facebook')
  end

  def facebook_token
    facebook_identity.try(:token)
  end

  def picasa_identity
    @picasa_identity ||= has_provider_auth('google_oauth2')
  end

  # returns nil or the twitter ProviderAuthorization
  def twitter_identity
    @twitter_identity ||= has_provider_auth('twitter')
  end

  def api_token
    JsonWebToken.encode( user_id: id )
  end

  def orcid
    provider_authorizations.
      detect{ |pa| pa.provider_name == "orcid" }.try( :provider_uid )
  end

  def update_observation_licenses
    return true unless [true, "1", "true"].include?(@make_observation_licenses_same)
    Observation.where(user_id: id).update_all(license: preferred_observation_license)
    index_observations_later
    true
  end
  
  def update_photo_licenses
    return true unless [true, "1", "true"].include?(@make_photo_licenses_same)
    number = Photo.license_number_for_code(preferred_photo_license)
    return true unless number
    Photo.where(["user_id = ? AND type != 'GoogleStreetViewPhoto'", id]).update_all(license: number)
    index_observations_later
    true
  end

  def update_sound_licenses
    return true unless [true, "1", "true"].include?(@make_sound_licenses_same)
    number = Photo.license_number_for_code(preferred_sound_license)
    return true unless number
    Sound.where(user_id: id).update_all(license: number)
    index_observations_later
    true
  end

  def update_observation_sites_later
    delay(priority: USER_INTEGRITY_PRIORITY).update_observation_sites if site_id_changed?
  end

  def update_observation_sites
    observations.update_all(site_id: site_id)
    index_observations
  end

  def index_observations_later
    delay(
      priority: USER_INTEGRITY_PRIORITY,
      unique_hash: { "User::index_observations_later": id }
    ).index_observations
  end

  def index_observations
    Observation.elastic_index!(scope: Observation.by(self))
  end

  def merge(reject)
    raise "Can't merge a user with itself" if reject.id == id
    life_list_taxon_ids_to_move = reject.life_list.taxon_ids - life_list.taxon_ids
    ListedTaxon.where(list_id: reject.life_list_id, taxon_id: life_list_taxon_ids_to_move).
      update_all(list_id: life_list_id)
    reject.friendships.where(friend_id: id).each{ |f| f.destroy }
    merge_has_many_associations(reject)
    reject.destroy
    User.delay( priority: USER_INTEGRITY_PRIORITY ).merge_cleanup( id )
  end

  def self.merge_cleanup( user_id )
    return unless user = User.find_by_id( user_id )
    start = Time.now
    Observation.elastic_index!( scope: Observation.by( user_id ) )
    Observation.elastic_index!(
      scope: Observation.joins( :identifications ).
        where( "identifications.user_id = ?", user_id ).
        where( "observations.last_indexed_at < ?", start )
    )
    Identification.elastic_index!( scope: Identification.where( user_id: user_id ) )
    User.update_identifications_counter_cache( user.id )
    User.update_observations_counter_cache( user.id )
    user.reload
    user.elastic_index!
    LifeList.reload_from_observations( user.life_list_id )
  end

  def set_locale
    self.locale = I18n.locale if locale.blank?
    true
  end

  def set_time_zone
    self.time_zone = nil if time_zone.blank?
    true
  end

  def set_uri
    if uri.blank?
      User.where(id: id).update_all(uri: FakeView.user_url(id))
    end
    true
  end
    
  def get_lat_lon_from_ip
    return true if last_ip.nil?
    latitude = nil
    longitude = nil
    lat_lon_acc_admin_level = nil
    geoip_response = INatAPIService.geoip_lookup({ ip: last_ip })
    if geoip_response && geoip_response.results
      # don't set any location if the country is unknown
      if geoip_response.results.country
        ll = geoip_response.results.ll
        latitude = ll[0]
        longitude = ll[1]
        if geoip_response.results.city
          # also probably know the county
          lat_lon_acc_admin_level = 2
        elsif geoip_response.results.region
          # also probably know the state
          lat_lon_acc_admin_level = 1
        else
          # probably just know the country
          lat_lon_acc_admin_level = 0
        end
      end
    end
    self.latitude = latitude
    self.longitude = longitude
    self.lat_lon_acc_admin_level = lat_lon_acc_admin_level
  end
  
  def get_lat_lon_from_ip_if_last_ip_changed
    return true if last_ip.nil?
    if last_ip_changed? || latitude.nil?
      get_lat_lon_from_ip
    end
  end

  def check_suspended_by_user
    return if suspended?
    self.suspended_by_user_id = nil
  end

  def published_name
    name.blank? ? login : name
  end
  
  def self.query(params={}) 
    scope = self.all
    if params[:sort_by] && params[:sort_dir]
      scope.order(params[:sort_by], params[:sort_dir])
    elsif params[:sort_by]
      params.order(query[:sort_by])
    end
    scope
  end
  
  def self.find_for_authentication(conditions = {})
    s = conditions[:email].to_s.downcase
    where("lower(login) = ?", s).first || where("lower(email) = ?", s).first
  end
  
  # http://stackoverflow.com/questions/6724494
  def self.authenticate(login, password)
    user = User.find_for_authentication(:email => login)
    return nil if user.blank?
    user.valid_password?(password) && user.active? ? user : nil
  end

  # create a user using 3rd party provider credentials (via omniauth)
  # note that this bypasses validation and immediately activates the new user
  # see https://github.com/intridea/omniauth/wiki/Auth-Hash-Schema for details of auth_info data
  def self.create_from_omniauth(auth_info)
    email = auth_info["info"].try(:[], "email")
    email ||= auth_info["extra"].try(:[], "user_hash").try(:[], "email")
    # see if there's an existing inat user with this email. if so, just link the accounts and return the existing user.
    if email && u = User.find_by_email(email)
      u.add_provider_auth(auth_info)
      return u
    end
    auth_info_name = auth_info["info"]["nickname"]
    auth_info_name = auth_info["info"]["first_name"] if auth_info_name.blank?
    auth_info_name = auth_info["info"]["name"] if auth_info_name.blank?
    autogen_login = User.suggest_login(auth_info_name)
    autogen_login = User.suggest_login(email.split('@').first) if autogen_login.blank? && !email.blank?
    autogen_login = User.suggest_login('naturalist') if autogen_login.blank?
    autogen_pw = SecureRandom.hex(6) # autogenerate a random password (or else validation fails)
    icon_url = auth_info["info"]["image"]
    # Don't bother if the icon URL looks like the default Google user icon
    icon_url = nil if icon_url =~ /4252rscbv5M/
    u = User.new(
      :login => autogen_login,
      :email => email,
      :name => auth_info["info"]["name"],
      :password => autogen_pw,
      :password_confirmation => autogen_pw,
      :icon_url => icon_url
    )
    u.skip_email_validation = true
    u.skip_confirmation!
    user_saved = begin
      u.save
    rescue PG::Error, ActiveRecord::RecordNotUnique => e
      raise e unless e.message =~ /duplicate key value violates unique constraint/
      false
    end
    unless user_saved
      suggestion = User.suggest_login(u.login)
      Rails.logger.info "[INFO #{Time.now}] unique violation on #{u.login}, suggested login: #{suggestion}"
      u.update_attributes(:login => suggestion)
    end
    u.add_provider_auth(auth_info)
    u
  end

  # given a requested login, will try to find existing users with that login
  # and suggest handle2, handle3, handle4, etc if the login's taken
  # to prevent namespace clashes (e.g. i register with twitter @joe but 
  # there's already an inat user where login=joe, so it suggest joe2)
  def self.suggest_login(requested_login)
    requested_login = requested_login.to_s
    requested_login = "naturalist" if requested_login.blank?
    # strip out everything but letters and numbers so we can pass the login format regex validation
    requested_login = requested_login.sub(/^\d*/, '').downcase.split('').select do |l|
      ('a'..'z').member?(l) || ('0'..'9').member?(l)
    end.join('')
    requested_login = "naturalist" if requested_login.blank?
    suggested_login = requested_login

    if suggested_login.size > MAX_LOGIN_SIZE
      suggested_login = suggested_login[0..MAX_LOGIN_SIZE/2]
    end

    appendix = 1
    while suggested_login.to_s.size < MIN_LOGIN_SIZE || User.find_by_login(suggested_login)
      suggested_login = "#{requested_login}#{appendix}"
      appendix += 1
    end

    (MIN_LOGIN_SIZE..MAX_LOGIN_SIZE).include?(suggested_login.size) ? suggested_login : nil
  end

  # Destroying a user triggers a giant, slow, costly cascade of deletions that
  # all occur within a transaction. This method tries to circumvent some of
  # that madness by assigning communal assets to new users and pre-destroying
  # some associates
  def sane_destroy(options = {})
    start_log_timer "sane_destroy user #{id}"
    taxon_ids = life_list.taxon_ids
    project_ids = self.project_ids

    # delete lists without triggering most of the callbacks
    lists.where("type = 'List'").find_each do |l|
      l.listed_taxa.find_each do |lt|
        lt.skip_sync_with_parent = true
        lt.skip_update_cache_columns = true
        lt.skip_update_user_life_list_taxa_count = true
        lt.destroy
      end
      l.destroy
    end

    User.preload_associations(self, [ :stored_preferences, :roles, :flags ])
    # delete observations without onerous callbacks
    observations.includes([
      { user: :stored_preferences },
      :votes_for,
      :flags,
      :stored_preferences,
      :observation_photos,
      :comments,
      :annotations,
      { identifications: [
        :taxon,
        :user,
        :flags
      ] },
      :project_observations,
      :project_invitations,
      :quality_metrics,
      :observation_field_values,
      :observation_sounds,
      :observation_reviews,
      { listed_taxa: :list },
      :tags,
      :taxon,
      :quality_metrics,
      :sounds
    ]).find_each(batch_size: 100) do |o|
      o.skip_refresh_lists = true
      o.skip_refresh_check_lists = true
      o.skip_identifications = true
      o.bulk_delete = true
      o.comments.each{ |c| c.bulk_delete = true }
      o.annotations.each{ |a| a.bulk_delete = true }
      o.destroy
    end

    identification_observation_ids = Identification.where(user_id: id).
      select(:observation_id).distinct.pluck(:observation_id)
    comment_observation_ids = Comment.where(user_id: id, parent_type: "Observation").
      select(:parent_id).distinct.pluck(:parent_id)
    annotation_observation_ids = Annotation.where(user_id: id, resource_type: "Observation").
      select(:resource_id).distinct.pluck(:resource_id)
    unique_obs_ids = ( identification_observation_ids + comment_observation_ids +
      annotation_observation_ids ).uniq

    identifications.includes([
      :observation,
      :taxon,
      :user,
      :flags
    ]).find_each(batch_size: 100) do |i|
      i.observation.skip_indexing = true
      i.observation.bulk_delete = true
      i.bulk_delete = true
      i.destroy
    end

    identification_observation_ids.in_groups_of(100, false) do |obs_ids|
      Observation.where(id: obs_ids).includes(
        { user: :stored_preferences },
        :votes_for,
        :flags,
        :taxon,
        { photos: :flags },
        { identifications: [ :taxon, { user: :flags } ] },
        :quality_metrics
      ).each do |o|
        Identification.update_categories_for_observation( o, { skip_reload: true, skip_indexing: true } )
        o.update_stats
      end
      Identification.elastic_index!(scope: Identification.where(observation_id: obs_ids))
    end

    comments.find_each(batch_size: 100) do |c|
      c.bulk_delete = true
      c.destroy
    end

    annotations.includes(:votes_for).find_each(batch_size: 100) do |a|
      a.votes_for.each{ |v| v.bulk_delete = true }
      a.bulk_delete = true
      a.destroy
    end

    # transition ownership of projects with observations, delete the rest
    Project.where(:user_id => id).find_each do |p|
      if p.observations.exists?
        if manager = p.project_users.managers.where("user_id != ?", id).first
          p.user = manager.user
          manager.role_will_change!
          manager.save
        else
          pu = ProjectUser.create(:user => User.admins.first, :project => p)
          p.user = pu.user
        end
        p.save
      else
        p.destroy
      end
    end

    Observation.elastic_index!(ids: unique_obs_ids )

    # delete the user
    destroy

    # refresh check lists with relevant taxa
    taxon_ids.in_groups_of(100) do |group|
      CheckList.delay(:priority => OPTIONAL_PRIORITY, :queue => "slow").refresh(:taxa => group.compact)
    end

    # refresh project lists
    project_ids.in_groups_of(100) do |group|
      ProjectList.delay(:priority => INTEGRITY_PRIORITY).refresh(:taxa => group.compact)
    end

    end_log_timer
  end

  #
  #  Wipes all the data related to a user, within reason (can't do backups).
  #  Only for extreme cases and compliance with privacy regulations. Do not
  #  expose in the UI.
  #
  def self.forget( user_id, options = {} )
    if user_id.blank?
      raise "User ID cannot be blank"
    end
    if user = User.find_by_id( user_id )
      puts "Destroying user (this could take a while)"
      user.sane_destroy
    end

    puts "Updating flags created by user..."
    Flag.where( user_id: user_id ).update_all( user_id: -1 )

    deleted_observations = DeletedObservation.where( user_id: user_id )
    puts "Deleting #{deleted_observations.count} DeletedObservations"
    deleted_observations.delete_all

    unless options[:skip_aws]
      s3_config = YAML.load_file( File.join( Rails.root, "config", "s3.yml") )
      s3_client = ::Aws::S3::Client.new(
        access_key_id: s3_config["access_key_id"],
        secret_access_key: s3_config["secret_access_key"],
        region: CONFIG.s3_region
      )
      cf_client = ::Aws::CloudFront::Client.new(
        access_key_id: s3_config["access_key_id"],
        secret_access_key: s3_config["secret_access_key"],
        region: CONFIG.s3_region
      )

      deleted_photos = DeletedPhoto.where( user_id: user_id )
      puts "Deleting #{deleted_photos.count} DeletedPhotos and associated records from s3"
      deleted_photos.find_each do |dp|
        images = s3_client.list_objects( bucket: CONFIG.s3_bucket, prefix: "photos/#{ dp.photo_id }/" ).contents
        puts "\tPhoto #{dp.photo_id}, removing #{images.size} images from S3"
        if images.any?
          s3_client.delete_objects( bucket: CONFIG.s3_bucket, delete: { objects: images.map{|s| { key: s.key } } } )
        end
        dp.destroy
      end

      # delete user profile pic form s3
      user_images = s3_client.list_objects( bucket: CONFIG.s3_bucket, prefix: "attachments/users/icons/#{user_id}/" ).contents
      if user_images.any?
        puts "Deleting profile pic from S3"
        s3_client.delete_objects( bucket: CONFIG.s3_bucket, delete: { objects: user_images.map{|s| { key: s.key } } } )
      end

      # This might cause problems with multiple simultaneous invalidations. FWIW,
      # CloudFront is supposed to expire things in 24 hours by default
      if options[:cloudfront_distribution_id]
        paths = deleted_photos.compact.map{|dp| "/photos/#{ dp.photo_id }/*" }
        if user_images.any?
          paths << "attachments/users/icons/#{user_id}/*"
        end
        cf_client.create_invalidation(
          distribution_id: options[:cloudfront_distribution_id],
          invalidation_batch: {
            paths: {
              quantity: paths.size,
              items: paths
            },
            caller_reference: "#{paths[0]}/#{Time.now.to_i}"
          }
        )
      end

      deleted_sounds = DeletedSound.where( user_id: user_id )
      puts "Deleting #{deleted_sounds.count} DeletedSounds and associated records from s3"
      deleted_sounds.find_each do |ds|
        sounds = s3_client.list_objects( bucket: CONFIG.s3_bucket, prefix: "sounds/#{ ds.sound_id }." ).contents
        puts "\tSound #{ds.sound_id}, removing #{sounds.size} sounds from S3"
        if sounds.any?
          s3_client.delete_objects( bucket: CONFIG.s3_bucket, delete: { objects: sounds.map{|s| { key: s.key } } } )
        end
        ds.destroy
      end
    end

    # Delete from PandionES where user_id:user_id
    if options[:logstash_es_host]
      logstash_es_client = Elasticsearch::Client.new(
        host: options[:logstash_es_host],
      )
      puts "Deleting logstash records"
      begin
        logstash_es_client.delete_by_query(
          index: "logstash-*",
          body: {
            query: {
              term: {
                user_id: user_id
              }
            }
          }
        )
      rescue Faraday::TimeoutError, Net::ReadTimeout
        retry
      end
    else
      puts "Logstash ES host not configured. You may have to manually remove log entries for this user."
    end

    puts "Deleting DeletedUser"
    DeletedUser.where( user_id: user_id ).delete_all

    # Trigger sync on all staging servers
    puts
    puts "Ensure all staging servers get synced"
    puts
  end
  
  def create_default_life_list
    return true if life_list
    new_life_list = if (existing = self.lists.joins(:rules).where("lists.type = 'LifeList' AND list_rules.id IS NULL").first)
      self.life_list = existing
    else
      LifeList.create(:user => self)
    end
    User.where(id: id).update_all(life_list_id: new_life_list)
    true
  end
  
  def create_deleted_user
    DeletedUser.create(
      :user_id => id,
      :login => login,
      :email => email,
      :user_created_at => created_at,
      :user_updated_at => updated_at,
      :observations_count => observations_count
    )
    true
  end

  def remove_oauth_access_tokens
    return true unless frozen?
    Doorkeeper::AccessToken.where( resource_owner_id: id ).delete_all
    true
  end

  def destroy_project_rules
    ProjectObservationRule.where(
      operand_type: "User",
      operand_id: id
    ).destroy_all
  end

  def self.reindex_faved_observations_after_destroy( user_id )
    while true
      obs = Observation.elastic_search(
        _source: [:id],
        limit: 200,
        where: {
          nested: {
            path: "votes",
            query: {
              bool: {
                filter: {
                  term: {
                    "votes.user_id": user_id
                  }
                }
              }
            }
          }
        }
      ).results.results
      break if obs.blank?
      Observation.elastic_index!( ids: obs.map(&:id) )
    end
  end

  def reindex_faved_observations_after_destroy_later
    User.delay.reindex_faved_observations_after_destroy( id )
    true
  end

  def generate_csv(path, columns, options = {})
    of_names = ObservationField.joins(observation_field_values: :observation).
      where("observations.user_id = ?", id).
      select("DISTINCT observation_fields.name").
      map{|of| "field:#{of.normalized_name}"}
    columns += of_names
    columns -= %w(user_id user_login)
    CSV.open(path, 'w') do |csv|
      csv << columns
      self.observations.includes(:taxon, {:observation_field_values => :observation_field}).find_each do |observation|
        csv << columns.map{|c| observation.send(c) rescue nil}
      end
    end
  end

  def destroy_messages_by_suspended_user
    return true unless suspended?
    Message.inbox.unread.where(:from_user_id => id).destroy_all
    true
  end

  def revoke_access_tokens_by_suspended_user
    return true unless suspended?
    Doorkeeper::AccessToken.where( resource_owner_id: id ).each(&:revoke)
    true
  end

  def restore_access_tokens_by_suspended_user
    return true if suspended?
    if suspended_at_changed?
      # This is not an ideal solution because there are reasons to revoke a
      # token that are not related to suspension, like trying to deal with a
      # oauth app that's behaving badly for some reason, or a user's token is
      # stolen and someone else is using it, but I'm hoping those are rare
      # situations that we can deal with by deleting tokens
      Doorkeeper::AccessToken.where( resource_owner_id: id ).update_all( revoked_at: nil )
    end
    true
  end

  def set_observations_taxa_if_pref_changed
    if prefers_community_taxa_changed? && !id.blank?
      Observation.delay( priority: USER_INTEGRITY_PRIORITY ).set_observations_taxa_for_user( id )
    end
    true
  end

  def reassess_coordinate_obscuration_if_pref_changed
    if prefers_coordinate_interpolation_protection_changed? && !id.blank?
      Observation.delay( priority: USER_INTEGRITY_PRIORITY ).reassess_coordinates_for_observations_by( id )
    end
    true
  end

  def update_life_list
    if login_changed? && life_list
      life_list.update_attributes( title: life_list.title.gsub( /#{login_was}/, login ) )
    end
    true
  end

  def update_photo_properties
    changes = {}
    changes[:native_username] = login if login_changed?
    changes[:native_realname] = name if name_changed?
    unless changes.blank?
      delay( priority: USER_INTEGRITY_PRIORITY ).update_photos_with_changes( changes )
    end
    true
  end

  def update_photos_with_changes( changes )
    return if changes.blank?
    photos.update_all( changes )
  end

  def recent_notifications(options={})
    return [] if CONFIG.has_subscribers == :disabled
    options[:filters] = options[:filters] ? options[:filters].dup : [ ]
    options[:inverse_filters] = options[:inverse_filters] ? options[:inverse_filters].dup : [ ]
    options[:per_page] ||= 10
    if options[:unviewed]
      options[:inverse_filters] << { term: { viewed_subscriber_ids: id } }
    elsif options[:viewed]
      options[:filters] << { term: { viewed_subscriber_ids: id } }
    end
    options[:filters] << { term: { subscriber_ids: id } }
    ops = {
      filters: options[:filters],
      inverse_filters: options[:inverse_filters],
      per_page: options[:per_page],
      sort: { id: :desc }
    }
    UpdateAction.elastic_paginate(
      filters: options[:filters],
      inverse_filters: options[:inverse_filters],
      per_page: options[:per_page],
      sort: { id: :desc })
  end

  def blocked_by?( user )
    user_blocks_as_blocked_user.where( user_id: user ).exists?
  end

  def self.default_json_options
    {
      only: [
        :id,
        :login,
        :name,
        :created,
        :observations_count,
        :identifications_count
      ],
      methods: [
        :user_icon_url,
        :medium_user_icon_url,
        :original_user_icon_url
      ]
    }
  end

  def self.active_ids(at_time = Time.now)
    date_range = (at_time - 30.days)..at_time
    classes = [ Identification, Observation, Comment, Post ]
    # get the unique user_ids that created instances of any of these
    # classes within the last 30 days, then get the union (with .inject(:|))
    # of the array of arrays.
    user_ids = classes.collect{ |klass|
      klass.select("DISTINCT(user_id)").where(created_at: date_range).
        collect{ |i| i.user_id }
    }.inject(:|)
  end

  def self.header_cache_key_for(user, options = {})
    user_id = user.is_a?(User) ? user.id : user
    user_id ||= "signed_on"
    site_name = options[:site].try(:name) || options[:site_name]
    site_name ||= user.site.try(:name) if user.is_a?(User)
    version = ApplicationController::HEADER_VERSION
    "header_cache_key_for_#{user_id}_on_#{site_name}_#{I18n.locale}_#{version}"
  end

  def self.update_identifications_counter_cache(user_id)
    return unless user = User.find_by_id(user_id)
    new_fields_result = Observation.elastic_search(
      filters: [
        { term: { non_owner_identifier_user_ids: user_id } }
      ],
      size: 0,
      track_total_hits: true
    )
    count = (new_fields_result && new_fields_result.response) ?
      new_fields_result.response.hits.total.value : 0
    User.where(id: user_id).update_all(identifications_count: count)
  end

  def self.update_observations_counter_cache(user_id)
    return unless user = User.find_by_id( user_id )
    result = Observation.elastic_search(
      filters: [
        { bool: { must: [
          { term: { "user.id": user_id } },
        ] } }
      ],
      size: 0,
      track_total_hits: true
    )
    count = (result && result.response) ? result.response.hits.total.value : 0
    User.where( id: user_id ).update_all( observations_count: count )
    user.reload
    user.elastic_index!
  end

  def to_plain_s
    "User #{login}"
  end

  def subscribed_to?(resource)
    subscriptions.where(resource: resource).exists?
  end

  def recent_observation_fields
    ObservationField.recently_used_by(self).limit(10)
  end

  def test_groups_array
    test_groups.to_s.split( "|" )
  end

  def in_test_group?( group )
    test_groups_array.include?( group)
  end

  def flagged_with( flag, options = {} )
    evaluate_new_flag_for_spam( flag )
    elastic_index!
    Observation.elastic_index!( scope: Observation.by( id ), delay: true )
    Identification.elastic_index!( scope: Identification.where( user_id: id ), delay: true )
    Project.elastic_index!( scope: Project.where( user_id: id ), delay: true )
  end

  def personal_lists
    lists.not_flagged_as_spam.
      where("(type IN ('LifeList', 'List') OR type IS NULL)")
  end

  def privileged_with?( privilege )
    user_privileges.where( privilege: privilege ).where( "revoked_at IS NULL" ).exists?
  end

  def set_pi_consent_at
    if pi_consent
      self.pi_consent_at = Time.now
    end
    true
  end

  def donor?
    donorbox_donor_id.to_i > 0
  end

  def display_donor_since
    return nil unless prefers_monthly_supporter_badge?
    donorbox_plan_status == "active" &&
      donorbox_plan_type == "monthly" &&
      donorbox_plan_started_at
  end

  # Iterates over recently created accounts of unknown spammer status, zero
  # obs or ids, and a description with a link. Attempts to run them past
  # akismet three times, which seems to catch most spammers
  def self.check_recent_probable_spammers( limit = 100 )
    spammers = []
    num_checks = {}
    User.order( "id desc" ).limit( limit ).
        where( "spammer is null " ).
        where( "created_at < ? ", 12.hours.ago ). # half day grace period
        where( "description is not null and description != '' and description ilike '%http%'" ).
        where( "observations_count = 0 and identifications_count = 0" ).
        pluck(:id).
        in_groups_of( 10 ) do |ids|
      puts
      puts "BATCH #{ids[0]}"
      puts
      3.times do |i|
        batch = User.where( "id IN (?)", ids )
        puts "Try #{i}"
        batch.each do |u|
          next if spammers.include?( u.login )
          num_checks[u.login] ||= 0
          puts "#{u}, checked #{num_checks[u.login]} times already"
          num_checks[u.login] += 1
          u.description_will_change!
          u.check_for_spam
          puts "\tu.akismet_response: #{u.akismet_response}"
          u.reload
          if u.spammer == true
            puts "\tSPAM"
            spammers << u.login
          end
          sleep 1
        end
        sleep 10
      end
    end
  end

end
