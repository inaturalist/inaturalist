# would've liked to call this simply Authorization, but that model name clashes with restful_authentication
class ProviderAuthorization < ActiveRecord::Base
  belongs_to  :user
  validates_presence_of :user_id, :provider_uid, :provider_name
  validates_uniqueness_of :provider_uid, :scope => :provider_name

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

end
