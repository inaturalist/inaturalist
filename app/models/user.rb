class User < ActiveRecord::Base
  
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
  attr_accessible :make_observation_licenses_same, 
                  :make_photo_licenses_same,
                  :make_sound_licenses_same, 
                  :preferred_photo_license, 
                  :preferred_observation_license,
                  :preferred_sound_license
  attr_accessor :html
  
  preference :project_journal_post_email_notification, :boolean, :default => true
  preference :comment_email_notification, :boolean, :default => true
  preference :identification_email_notification, :boolean, :default => true
  preference :message_email_notification, :boolean, :default => true
  preference :no_email, :boolean, :default => false
  preference :project_invitation_email_notification, :boolean, :default => true
  preference :lists_by_login_sort, :string, :default => "id"
  preference :lists_by_login_order, :string, :default => "asc"
  preference :per_page, :integer, :default => 30
  preference :gbif_sharing, :boolean, :default => true
  preference :observation_license, :string
  preference :photo_license, :string
  preference :sound_license, :string
  preference :share_observations_on_facebook, :boolean, :default => true
  preference :share_observations_on_twitter, :boolean, :default => true
  preference :automatic_taxonomic_changes, :boolean, :default => true
  preference :observations_view, :string

  
  SHARING_PREFERENCES = %w(share_observations_on_facebook share_observations_on_twitter)
  NOTIFICATION_PREFERENCES = %w(comment_email_notification identification_email_notification 
    message_email_notification project_invitation_email_notification 
    project_journal_post_email_notification)
  
  belongs_to :life_list, :dependent => :destroy
  has_many  :provider_authorizations, :dependent => :delete_all
  has_one  :flickr_identity, :dependent => :delete
  has_one  :picasa_identity, :dependent => :delete
  has_one  :soundcloud_identity, :dependent => :delete
  has_many :observations, :dependent => :destroy
  
  # Some interesting ways to map self-referential relationships in rails
  has_many :friendships, :dependent => :destroy
  has_many :friends, :through => :friendships
  has_many :stalkerships, :class_name => 'Friendship', :foreign_key => 'friend_id', :dependent => :destroy
  has_many :followers, :through => :stalkerships,  :source => 'user'
  
  has_many :lists, :dependent => :destroy
  has_many :life_lists
  has_many :identifications, :dependent => :destroy
  has_many :identifications_for_others, :class_name => "Identification", 
    :include => [:observation],
    :conditions => "identifications.user_id != observations.user_id AND identifications.current = true"
  has_many :photos, :dependent => :destroy
  has_many :posts #, :dependent => :destroy
  has_many :journal_posts, :class_name => Post.to_s, :as => :parent, :dependent => :destroy
  has_many :taxon_links, :dependent => :nullify
  has_many :comments, :dependent => :destroy
  has_many :projects #, :dependent => :nullify
  has_many :project_users, :dependent => :destroy
  has_many :listed_taxa, :dependent => :nullify
  has_many :invites, :dependent => :nullify
  has_many :quality_metrics, :dependent => :destroy
  has_many :sources, :dependent => :nullify
  has_many :places, :dependent => :nullify
  has_many :messages, :dependent => :destroy
  has_many :guides, :dependent => :nullify, :inverse_of => :user
  
  has_attached_file :icon, 
    :styles => { :medium => "300x300>", :thumb => "48x48#", :mini => "16x16#" },
    :processors => [:deanimator],
    :path => ":rails_root/public/attachments/:class/:attachment/:id-:style.:icon_type_extension",
    :url => "/attachments/:class/:attachment/:id-:style.:icon_type_extension",
    :default_url => "/attachment_defaults/:class/:attachment/defaults/:style.png"

  # Roles
  has_and_belongs_to_many :roles
  
  has_subscribers
  has_many :subscriptions, :dependent => :delete_all
  has_many :updates, :foreign_key => :subscriber_id, :dependent => :delete_all

  before_validation :download_remote_icon, :if => :icon_url_provided?
  before_validation :strip_name
  before_save :whitelist_licenses
  after_save :update_observation_licenses
  after_save :update_photo_licenses
  after_save :update_sound_licenses
  after_create :create_default_life_list
  after_create :set_uri
  after_destroy :create_deleted_user

  validates_presence_of :icon_url, :if => :icon_url_provided?, :message => 'is invalid or inaccessible'
  validates_attachment_content_type :icon, :content_type => [/jpe?g/i, /png/i, /gif/i], 
    :message => "must be JPG, PNG, or GIF"

  validates_presence_of     :login
  
  MIN_LOGIN_SIZE = 3
  MAX_LOGIN_SIZE = 40
  
  # Regexes from restful_authentication
  login_regex       = /\A[A-z][\w\-_]+\z/                          # ASCII, strict
  bad_login_message = "use only letters, numbers, and -_ please.".freeze
  email_name_regex  = '[\w\.%\+\-]+'.freeze
  domain_head_regex = '(?:[A-Z0-9\-]+\.)+'.freeze
  domain_tld_regex  = '(?:[A-Z]{2}|com|org|net|edu|gov|mil|biz|info|mobi|name|aero|jobs|museum)'.freeze
  email_regex       = /\A#{email_name_regex}@#{domain_head_regex}#{domain_tld_regex}\z/i
  bad_email_message = "should look like an email address.".freeze
  
  validates_length_of       :login,    :within => MIN_LOGIN_SIZE..MAX_LOGIN_SIZE
  validates_uniqueness_of   :login
  validates_format_of       :login,    :with => login_regex, :message => bad_login_message

  validates_length_of       :name,     :maximum => 100, :allow_blank => true

  validates_format_of       :email,    :with => email_regex, :message => bad_email_message, :allow_blank => true
  validates_length_of       :email,    :within => 6..100, :allow_blank => true #r@a.wk
  validates_uniqueness_of   :email,    :allow_blank => true

  # HACK HACK HACK -- how to do attr_accessible from here?
  # prevents a user from submitting a crafted form that bypasses activation
  # anything else you want your user to change should be added here.
  attr_accessible :login, :email, :name, :password, :password_confirmation, :icon, :description, :time_zone, :icon_url, :locale
  
  scope :order_by, Proc.new { |sort_by, sort_dir|
    sort_dir ||= 'DESC'
    order("? ?", sort_by, sort_dir)
  }
  scope :curators, includes(:roles).where("roles.name IN ('curator', 'admin')")
  scope :admins, includes(:roles).where("roles.name = 'admin'")
  scope :active, where("suspended_at IS NULL")

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
    "#{FakeView.root_url}#{icon.url(:thumb)}".gsub(/([^\:])\/\//, '\\1/')
  end

  def active?
    !suspended?
  end

  # This is a dangerous override in that it doesn't call super, thereby
  # ignoring the results of all the devise modules like confirmable. We do
  # this b/c we want all users to be able to sign in, even if unconfirmed, but
  # not if suspended.
  def active_for_authentication?
    active?
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
    return true unless name
    self.name = name.gsub(/[\s\n\t]+/, ' ').strip
    true
  end
  
  def whitelist_licenses
    unless preferred_observation_license.blank? || Observation::LICENSE_CODES.include?(preferred_observation_license)
      self.preferred_observation_license = nil
    end
    
    unless preferred_photo_license.blank? || Observation::LICENSE_CODES.include?(preferred_photo_license)
      self.preferred_photo_license = nil
    end
    true
  end

  # add a provider_authorization to this user.  
  # auth_info is the omniauth info from rack.
  def add_provider_auth(auth_info)
    provider_auth_info = {
      :provider_name => auth_info['provider'], 
      :provider_uid => auth_info['uid']
    }
    unless auth_info["credentials"].blank? # open_id (google, yahoo, etc) doesn't provide a token
      provider_auth_info.merge!(
        :token => auth_info["credentials"]["token"],
        :secret => auth_info["credentials"]["secret"]
      ) 
    end
    pa = self.provider_authorizations.build(provider_auth_info) 
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
    write_attribute :login, (value ? value.downcase : nil)
  end

  def email=(value)
    write_attribute :email, (value ? value.downcase : nil)
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
    observations.find(:all, :limit => num, :order => "created_at DESC")
  end

  # TODO: named_scope  
  def friends_observations(limit = 5)
    obs = []
    friends.each do |friend|
      obs << friend.observations.find(:all, :order => 'created_at DESC', :limit => limit)
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
  
  def to_s
    "<User #{self.id}: #{self.login}>"
  end
  
  def friends_with?(user)
    friends.exists?(user)
  end
  
  def picasa_client
    return nil unless picasa_identity
    @picasa_client ||= Picasa.new(self.picasa_identity.token)
  end

  # returns a koala object to make (authenticated) facebook api calls
  # e.g. @facebook_api.get_object('me')
  # see koala docs for available methods: https://github.com/arsduo/koala
  def facebook_api
    return nil unless facebook_identity
    @facebook_api ||= Koala::Facebook::GraphAndRestAPI.new(facebook_identity.token)
  end
  
  # returns nil or the facebook ProviderAuthorization
  def facebook_identity
    @facebook_identity ||= has_provider_auth('facebook')
  end

  def facebook_token
    facebook_identity.try(:token)
  end

  # returns a Twitter object to make (authenticated) api calls
  # see twitter gem docs for available methods: https://github.com/sferik/twitter
  def twitter_api
    return nil unless twitter_identity
    @twitter_api ||= Twitter::Client.new(
      :oauth_token => twitter_identity.token,
      :oauth_token_secret => twitter_identity.secret
    )
  end

  # returns nil or the twitter ProviderAuthorization
  def twitter_identity
    @twitter_identity ||= has_provider_auth('twitter')
  end
  
  def update_observation_licenses
    return true unless [true, "1", "true"].include?(@make_observation_licenses_same)
    Observation.update_all(["license = ?", preferred_observation_license], ["user_id = ?", id])
    true
  end
  
  def update_photo_licenses
    return true unless [true, "1", "true"].include?(@make_photo_licenses_same)
    number = Photo.license_number_for_code(preferred_photo_license)
    return true unless number
    Photo.update_all(["license = ?", number], ["user_id = ?", id])
    true
  end

  def update_sound_licenses
    return true unless [true, "1", "true"].include?(@make_sound_licenses_same)
    number = Photo.license_number_for_code(preferred_sound_license)
    return true unless number
    Sound.update_all(["license = ?", number], ["user_id = ?", id])
    true
  end
  
  def merge(reject)
    raise "Can't merge a user with itself" if reject.id == id
    life_list_taxon_ids_to_move = reject.life_list.taxon_ids - life_list.taxon_ids
    ListedTaxon.update_all(
      ["list_id = ?", life_list_id],
      ["list_id = ? AND taxon_id IN (?)", reject.life_list_id, life_list_taxon_ids_to_move]
    )
    reject.friendships.all(:conditions => ["friend_id = ?", id]).each{|f| f.destroy}
    merge_has_many_associations(reject)
    reject.destroy
    LifeList.delay.reload_from_observations(life_list_id)
  end

  def set_uri
    if uri.blank?
      User.update_all(["uri = ?", FakeView.user_url(id)], ["id = ?", id])
    end
    true
  end
  
  def self.query(params={}) 
    scope = self.scoped
    if params[:sort_by] && params[:sort_dir]
      scope.order(params[:sort_by], params[:sort_dir])
    elsif params[:sort_by]
      params.order(query[:sort_by])
    end
    scope
  end
  
  def self.find_for_authentication(conditions = {})
    s = conditions[:email].to_s.downcase
    active.where("lower(login) = ? OR lower(email) = ?", s, s).first
  end
  
  # http://stackoverflow.com/questions/6724494
  def self.authenticate(login, password)
    user = User.find_for_authentication(:email => login)
    return nil if user.blank?
    user.valid_password?(password) ? user : nil
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
    u = User.new(
      :login => autogen_login,
      :email => email,
      :name => auth_info["info"]["name"],
      :password => autogen_pw,
      :password_confirmation => autogen_pw,
      :icon_url => auth_info["info"]["image"]
    )
    u.skip_email_validation = true
    u.skip_confirmation!
    unless u.save
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
    requested_login = requested_login.downcase.split('').select do |l| 
      ('a'..'z').member?(l) || ('0'..'9').member?(l)
    end.join('')
    suggested_login = requested_login
    
    if suggested_login.size > MAX_LOGIN_SIZE
      suggested_login = suggested_login[0..MAX_LOGIN_SIZE/2]
    end
    
    appendix = 1
    while suggested_login.to_s.size < MIN_LOGIN_SIZE || User.find_by_login(suggested_login)
      appendix += 1 
      suggested_login = "#{requested_login}#{appendix}"
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

    # delete observations without onerous callbacks
    observations.find_each do |o|
      o.skip_refresh_lists = true
      o.skip_refresh_check_lists = true
      o.skip_identifications = true
      o.destroy
    end

    # delete the user
    destroy

    # refresh check lists with relevant taxa
    taxon_ids.in_groups_of(100) do |group|
      CheckList.delay(:priority => INTEGRITY_PRIORITY, :queue => "slow").refresh(:taxa => group.compact)
    end

    # refresh project lists
    project_ids.in_groups_of(100) do |group|
      ProjectList.delay(:priority => INTEGRITY_PRIORITY).refresh(:taxa => group.compact)
    end

    end_log_timer
  end
  
  def create_default_life_list
    return true if life_list
    new_life_list = if (existing = self.lists.includes(:rules).where("lists.type = 'LifeList' AND list_rules.id IS NULL").first)
      self.life_list = existing
    else
      LifeList.create(:user => self)
    end
    User.update_all(["life_list_id = ?", new_life_list], ["id = ?", self])
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

  def self.default_json_options
    {
      :except => [:crypted_password, :salt, :old_preferences, :activation_code, :remember_token, :last_ip,
        :suspended_at, :suspension_reason, :state, :deleted_at, :remember_token_expires_at, :email]
    }
  end

end
