module Ambidextrous
  IPHONE_APP_USER_AGENT_PATTERN = /Titanium/i
  ANDROID_APP_USER_AGENT_PATTERN = /^iNaturalist\/\d+.+Android/i
  MOBILE_APP_USER_AGENT_PATTERNS = [IPHONE_APP_USER_AGENT_PATTERN, ANDROID_APP_USER_AGENT_PATTERN]
  
  protected
  def auth_url_for(provider, options = {})
    provider = provider.downcase
    openid_urls = {
      "google" => "https://www.google.com/accounts/o8/id",
      "yahoo" => "https://me.yahoo.com"
    }
    # if provider uses openid, url is of form /auth/open_id?openid_url=...
    # else url is simply /auth/:provider_name
    url = "/auth/"
    if openid_urls.has_key?(provider)
      url += 'open_id'
      options[:openid_url] = openid_urls[provider]
    else
      url += provider
    end
    url += "?" + options.map{|k,v| "#{k}=#{v}"}.join('&') unless options.blank?
    url
  end
  
  def is_android_app?
    (request.user_agent =~ ANDROID_APP_USER_AGENT_PATTERN).nil?
  end
  
  def is_iphone_app?
    (request.user_agent =~ IPHONE_APP_USER_AGENT_PATTERN).nil?
  end
  
  def is_mobile_app?
    is_android_app? || is_iphone_app?
  end
end
