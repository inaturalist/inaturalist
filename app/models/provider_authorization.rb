# would've liked to call this simply Authorization, but that model name clashes with restful_authentication
class ProviderAuthorization < ActiveRecord::Base
  belongs_to  :user
  validates_presence_of :user_id, :provider_uid, :provider_name
  validates_uniqueness_of :provider_uid, :scope => :provider_name  
  after_save :create_photo_identity
  
  # Hash that comes back from the provider through omniauth.  Should be set 
  # after the callback gets fired, so in theory should only be available when 
  # this record is created
  attr_accessor :auth_info
  
  PROVIDERS = %w(facebook twitter Flickr Google Yahoo) 
  AUTH_URLS = PROVIDERS.inject({}) do |memo, provider|
    memo.update(provider => "/auth/#{provider.downcase}")
  end
  AUTH_URLS.merge!(
    "Google" => "/auth/open_id?openid_url=https://www.google.com/accounts/o8/id",
    "Yahoo" => "/auth/open_id?openid_url=https://me.yahoo.com")
  ALLOWED_SCOPES = %w(read write)
  
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
    find_by_provider_name_and_provider_uid(auth_info['provider'], auth_info['uid'])
  end
  
  # Try to create a photo identity if the auth provider has/is a photo 
  # service
  def create_photo_identity
    photo_identity = case provider_name
    when "flickr"
      return if user.flickr_identity
      user.create_flickr_identity(
        :flickr_user_id => provider_uid || @auth_info.try(:[], "extra").try(:[], "user_hash").try(:[], "nsid"),
        :flickr_username => @auth_info.try(:[], "extra").try(:[], "user_hash").try(:[], "username"),
        :token => token,
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
  
  # right now this only needs to happen for flickr
  def update_photo_identities
    return unless token
    return unless provider_name == "flickr"
    return unless user.flickr_identity
    return if user.flickr_identity.token == token
    user.flickr_identity.update_attribute(:token, token)
  end
  
  def update_with_auth_info(auth_info)
    @auth_info = auth_info
    return unless auth_info["credentials"] # open_id (google, yahoo, etc) doesn't provide a token
    token = auth_info["credentials"]["token"] || auth_info["credentials"]["secret"]
    update_attribute(:token, token)
    update_photo_identities
  end

end
