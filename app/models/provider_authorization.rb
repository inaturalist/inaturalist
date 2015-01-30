# would've liked to call this simply Authorization, but that model name clashes with restful_authentication
class ProviderAuthorization < ActiveRecord::Base
  belongs_to  :user
  validates_presence_of :user_id, :provider_uid, :provider_name
  validates_uniqueness_of :provider_uid, :scope => :provider_name
  validate :uniqueness_of_authorization_per_user
  after_save :create_photo_identity, :create_sound_identity
  
  # Hash that comes back from the provider through omniauth.  Should be set 
  # after the callback gets fired, so in theory should only be available when 
  # this record is created
  attr_accessor :auth_info
  
  PROVIDERS = %w(facebook twitter flickr google_oauth2 yahoo soundcloud)
  PROVIDER_NAMES = PROVIDERS.inject({}) do |memo, provider|
    if provider == "google_oauth2"
      memo[provider] = "Google"
    elsif provider == "soundcloud"
      memo[provider] = "SoundCloud"
    else
      memo[provider] = provider.capitalize
    end
    memo
  end
  AUTH_URLS = PROVIDERS.inject({}) do |memo, provider|
    memo.update(provider => "/auth/#{provider.downcase}")
  end
  AUTH_URLS.merge!("yahoo" => "/auth/open_id?openid_url=https://me.yahoo.com")
  ALLOWED_SCOPES = %w(read write)

  def to_s
    "<ProviderAuthorization #{id} user_id: #{user_id} provider_name: #{provider_name}>"
  end

  def uniqueness_of_authorization_per_user
    existing_scope = if provider_uid =~ /google.com\/accounts/
      ProviderAuthorization.
        where(:provider_name => 'openid').
        where("provider_uid LIKE 'https://www.google.com/accounts%'").
        scoped
    elsif provider_uid =~ /me.yahoo.com/
      ProviderAuthorization.
        where(:provider_name => 'openid').
        where("provider_uid LIKE 'https://me.yahoo.com%'").
        scoped
    else
      ProviderAuthorization.where(:provider_name => provider_name)
    end
    existing_scope = existing_scope.where("id != ?", id) if id
    if existing_scope.where(:user_id => user_id).exists?
      errors.add(:user_id, "has already linked an account with #{provider}")
    end
    true
  end
  
  def provider
    if provider_uid =~ /google.com\/accounts/
      'google'
    elsif provider_uid =~ /me.yahoo.com/
      'yahoo'
    else
      provider_name
    end
  end

  def self.find_from_omniauth(auth_info)
    find_by_provider_name_and_provider_uid(auth_info['provider'], auth_info['uid'].to_s)
  end
  
  # Try to create a photo identity if the auth provider has/is a photo 
  # service
  def create_photo_identity
    photo_identity = case provider_name
    when "flickr"
      return if user.flickr_identity
      return unless auth_info
      
      user.create_flickr_identity(
        :flickr_user_id => provider_uid || auth_info['uid'],
        :flickr_username => auth_info['name'],
        :token => token,
        :secret => auth_info['credentials']['secret'],
        :token_created_at => Time.now
      )
    else
      nil
    end
    if photo_identity && !photo_identity.valid?
      Rails.logger.error "[ERROR #{Time.now}] Failed to save #{provider} " + 
        "photo identity after saving provider auth: " + 
        photo_identity.errors.full_messages.to_sentence
    end
    true
  end

  def create_sound_identity
    return unless provider_name == "soundcloud"
    return if user.soundcloud_identity || !auth_info
    user.create_soundcloud_identity(
      :native_username => auth_info['info']['nickname'],
      :native_realname => auth_info['info']['name']
    )
  end
  
  # right now this only needs to happen for flickr
  def update_photo_identities
    return unless token
    return unless provider_name == "flickr"
    return unless fi = user.flickr_identity
    fi.token = token
    secret = auth_info.try(:[], 'credentials').try(:[], 'secret')
    fi.secret = secret unless secret.blank?
    fi.save
    true
  end
  
  def update_with_auth_info(auth_info)
    @auth_info = auth_info
    return unless auth_info["credentials"] # open_id (google, yahoo, etc) doesn't provide a token
    token = auth_info["credentials"]["token"] || auth_info["credentials"]["secret"]
    secret = auth_info["credentials"]["secret"]
    update_attributes({:token => token, :secret => secret})
    update_photo_identities
  end

end
