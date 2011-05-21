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

  def self.find_from_omniauth(auth_info)
    return self.find_by_provider_name_and_provider_uid(auth_info['provider'], auth_info['uid'])
  end

  def self.auth_url_for(provider)
    provider = provider.downcase
    openid_urls = {
      "google"=>"https://www.google.com/accounts/o8/id",
      "yahoo"=>"https://me.yahoo.com"
    }
    # if provider uses openid, url is of form /auth/open_id?openid_url=...
    # else url is simply /auth/:provider_name
    return "/auth/#{(openid_urls.has_key?(provider) ? ("open_id?openid_url="+openid_urls[provider]) : provider)}"
  end
  
  # Trey to create a photo identity if the auth provider has/is a photo 
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

end
