require 'digest/sha1'
require 'open-uri'

class User < ActiveRecord::Base
  
  # If the user has this role, has_role? will always return true
  JEDI_MASTER_ROLE = 'admin'
  
  include Authentication
  include Authentication::ByPassword
  include Authentication::ByCookieToken
  include Authorization::AasmRoles
  
  # set user.skip_email_validation = true if you want to, um, skip email validation before creating+saving
  attr_accessor :skip_email_validation
  attr_accessor :skip_registration_email
  
  # licensing extras
  attr_accessor   :make_observation_licenses_same
  attr_accessor   :make_photo_licenses_same
  MASS_ASSIGNABLE_ATTRIBUTES = [:make_observation_licenses_same, :make_photo_licenses_same]
  
  # new way
  preference :comment_email_notification, :boolean, :default => true
  preference :identification_email_notification, :boolean, :default => true
  preference :project_invitation_email_notification, :boolean, :default => true
  preference :lists_by_login_sort, :string, :default => "id"
  preference :lists_by_login_order, :string, :default => "asc"
  preference :per_page, :integer, :default => 30
  preference :gbif_sharing, :boolean, :default => true
  preference :observation_license, :string
  preference :photo_license, :string
  
  NOTIFICATION_PREFERENCES = %w(comment_email_notification identification_email_notification project_invitation_email_notification)
  
  belongs_to :life_list, :dependent => :destroy
  has_many  :provider_authorizations, :dependent => :destroy
  has_one  :flickr_identity, :dependent => :destroy
  has_one  :picasa_identity, :dependent => :destroy
  has_many :observations, :dependent => :destroy
  
  # Some interesting ways to map self-referential relationships in rails
  has_many :friendships, :dependent => :destroy
  has_many :friends, :through => :friendships
  has_many :stalkerships, :class_name => 'Friendship', :foreign_key => 'friend_id', :dependent => :destroy
  has_many :followers, :through => :stalkerships,  :source => 'user'
  
  has_many :activity_stream_updates, :class_name => 'ActivityStream', :dependent => :destroy
  has_many :activity_streams, :foreign_key => 'subscriber_id'
  
  has_many :lists, :dependent => :destroy
  has_many :life_lists
  has_many :identifications, :dependent => :destroy
  has_many :photos, :dependent => :destroy
  has_many :goal_participants, :dependent => :destroy
  has_many :goals, :through => :goal_participants
  has_many :incomplete_goals,
           :source =>  :goal,
           :through => :goal_participants,
           :conditions => ["goal_participants.goal_completed = 0 " + 
                           "AND goals.completed = 0 " +
                           "AND (goals.ends_at IS NULL " +
                           "OR goals.ends_at > ?)", Time.now]
  has_many :completed_goals,
           :source => :goal,
           :through => :goal_participants,
           :conditions => "goal_participants.goal_completed = 1 " +
                          "OR goals.completed = 1"
  has_many :goal_participants_for_incomplete_goals,
           :class_name => "GoalParticipant",
           :include => :goal,
           :conditions => ["goal_participants.goal_completed = 0 " + 
                           "AND goals.completed = 0 " +
                           "AND (goals.ends_at IS NULL " +
                           "OR goals.ends_at > ?)", Time.now]
  has_many :goal_contributions, :through => :goal_participants
  
  has_many :posts, :dependent => :destroy
  has_many :journal_posts, :class_name => Post.to_s, :as => :parent
  has_many :taxon_links, :dependent => :nullify
  has_many :comments, :dependent => :destroy
  has_many :projects, :dependent => :destroy
  has_many :project_users, :dependent => :destroy
  has_many :listed_taxa, :dependent => :nullify
  has_many :invites, :dependent => :nullify
  has_many :quality_metrics, :dependent => :destroy
  has_many :sources, :dependent => :nullify
  has_many :places, :dependent => :nullify
  
  has_attached_file :icon, 
    :styles => { :medium => "300x300>", :thumb => "48x48#", :mini => "16x16#" },
    :path => ":rails_root/public/attachments/:class/:attachment/:id/:style/:basename.:extension",
    :url => "/attachments/:class/:attachment/:id/:style/:basename.:extension",
    :default_url => "/attachment_defaults/:class/:attachment/defaults/:style.png"

  # Roles
  has_and_belongs_to_many :roles

  before_validation :download_remote_icon, :if => :icon_url_provided?
  before_save :whitelist_licenses
  after_save :update_observation_licenses
  after_save :update_photo_licenses
  after_create :create_life_list, :signup_for_incomplete_community_goals
  after_destroy :create_deleted_user

  validates_presence_of :icon_url, :if => :icon_url_provided?, :message => 'is invalid or inaccessible'
  validates_attachment_content_type :icon, :content_type => [/jpe?g/i, /png/i, /gif/i], 
    :message => "must be JPG, PNG, or GIF"

  validates_presence_of     :login
  validates_length_of       :login,    :within => 3..40
  validates_uniqueness_of   :login
  validates_format_of       :login,    :with => Authentication.login_regex, :message => Authentication.bad_login_message

  validates_format_of       :name,     :with => Authentication.name_regex,  :message => Authentication.bad_name_message, :allow_nil => true
  validates_length_of       :name,     :maximum => 100, :allow_blank => true

  # only validate_presence_of email if user hasn't auth'd via a 3rd-party provider
  # you can also force skipping email validation by setting u.skip_email_validation=true before you save
  # (this option is necessary because the User is created before the associated ProviderAuthorization)
  validates_presence_of     :email,    :unless => Proc.new{|u| (u.skip_email_validation || (u.provider_authorizations.count > 0))}
  validates_format_of       :email,    :with => Authentication.email_regex, :message => Authentication.bad_email_message, :allow_blank => true
  validates_length_of       :email,    :within => 6..100, :allow_blank => true #r@a.wk
  validates_uniqueness_of   :email,    :allow_blank => true

  # HACK HACK HACK -- how to do attr_accessible from here?
  # prevents a user from submitting a crafted form that bypasses activation
  # anything else you want your user to change should be added here.
  attr_accessible :login, :email, :name, :password, :password_confirmation, :icon, :description, :time_zone, :icon_url
  
  named_scope :order, Proc.new { |sort_by, sort_dir|
    sort_dir ||= 'DESC'
    {:order => ("%s %s" % [sort_by, sort_dir])}
  }
  named_scope :curators, :include => [:roles], :conditions => "roles.name = 'curator'"
  
  def icon_url_provided?
    !self.icon_url.blank?
  end

  def download_remote_icon
    io = open(URI.parse(self.icon_url))
    self.icon = (io.base_uri.path.split('/').last.blank? ? nil : io)
    rescue # catch url errors with validations instead of exceptions (Errno::ENOENT, OpenURI::HTTPError, etc...)
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
    unless auth_info["credentials"].nil? # open_id (google, yahoo, etc) doesn't provide a token
      provider_auth_info.merge!({ :token => (auth_info["credentials"]["token"] || auth_info["credentials"]["secret"]) }) 
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
    provider_authorizations.all.select{|p| (p.provider_name == provider || p.provider_uid.match(provider))}.first
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
  
  def update_attributes(attributes)
    MASS_ASSIGNABLE_ATTRIBUTES.each do |a|
      self.send("#{a}=", attributes.delete(a.to_s)) if attributes.has_key?(a.to_s)
      self.send("#{a}=", attributes.delete(a)) if attributes.has_key?(a)
    end
    super(attributes)
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
    LifeList.send_later(:reload_from_observations, life_list_id)
  end
  
  def self.query(params={}) 
    scope = self.scoped({})
    if params[:sort_by] && params[:sort_dir]
      scope.order(params[:sort_by], params[:sort_dir])
    elsif params[:sort_by]
      params.order(query[:sort_by])
    end
    scope
  end
  
  # Authenticates a user by their login name and unencrypted password.  Returns the user or nil.
  #
  # uff.  this is really an authorization, not authentication routine.  
  # We really need a Dispatch Chain here or something.
  # This will also let us return a human error message.
  #
  def self.authenticate(login, password)
    return nil if login.blank? || password.blank?
    u = find_in_state :first, :active, :conditions => {:login => login}
    u = find_in_state :first, :active, :conditions => {:email => login} if u.nil?
    u && u.authenticated?(password) ? u : nil
  end

  # create a user using 3rd party provider credentials (via omniauth)
  # note that this bypasses validation and immediately activates the new user
  # see https://github.com/intridea/omniauth/wiki/Auth-Hash-Schema for details of auth_info data
  def self.create_from_omniauth(auth_info)
    email = (auth_info["user_info"]["email"] || auth_info["extra"]["user_hash"]["email"])
    # see if there's an existing inat user with this email. if so, just link the accounts and return the existing user.
    if email && u = User.find_by_email(email)
      u.add_provider_auth(auth_info)
      return u
    end
    autogen_login = User.suggest_login(
      auth_info["user_info"]["nickname"] || 
      auth_info["user_info"]["first_name"] || 
      auth_info["user_info"]["name"])
    autogen_login = User.suggest_login(email.split('@').first) if autogen_login.blank? && !email.blank?
    autogen_login = User.suggest_login('naturalist') if autogen_login.blank?
    autogen_pw = ActiveSupport::SecureRandom.base64(6) # autogenerate a random password (or else validation fails)
    u = User.new(
      :login => autogen_login,
      :email => email,
      :name => auth_info["user_info"]["name"],
      :password => autogen_pw,
      :password_confirmation => autogen_pw,
      :icon_url => auth_info["user_info"]["image"]
    )
    if u
      u.skip_email_validation = true
      u.skip_registration_email = true
      begin
        u.register!
        u.activate!
      rescue ActiveRecord::StatementInvalid => e
        raise e unless e.message =~ /unique constraint/
        u.login = User.suggest_login(u.login)
        Rails.logger.info "[INFO #{Time.now}] unique violation, suggested login: #{u.login}"
        u.register! unless u.pending?
        u.activate!
      end
      u.add_provider_auth(auth_info)
      # TODO: do something useful with location?  -> time zone, perhaps
    end
    u
  end
  
  protected

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
    appendix = 1
    while User.find_by_login(suggested_login)
      appendix += 1 
      suggested_login = "#{requested_login}#{appendix}"
    end  
    suggested_login
  end  
  
  def make_activation_code
    self.deleted_at = nil
    self.activation_code = self.class.make_token
  end
  
  # Everything below here was added for iNaturalist
  def create_life_list
    life_list = LifeList.create(:user => self)
    self.life_list = life_list
    self.save
  end
  
  def signup_for_incomplete_community_goals
    goals << Goal.for('community').incomplete.find(:all)
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

end
