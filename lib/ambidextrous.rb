module Ambidextrous
  IPHONE_APP_USER_AGENT_PATTERN_1 = /Titanium/i
  IPHONE_APP_USER_AGENT_PATTERN_2 = /^iNaturalist\/\d+.+iOS/i
  IPHONE_APP_USER_AGENT_PATTERN = /#{IPHONE_APP_USER_AGENT_PATTERN_1}|#{IPHONE_APP_USER_AGENT_PATTERN_2}/
  IPHONE_APP_USER_AGENT_PATTERNS = [IPHONE_APP_USER_AGENT_PATTERN, IPHONE_APP_USER_AGENT_PATTERN_2]
  ANDROID_APP_USER_AGENT_PATTERN = /^iNaturalist\/\d+.+Android/i
  MOBILE_APP_USER_AGENT_PATTERNS = [IPHONE_APP_USER_AGENT_PATTERNS, ANDROID_APP_USER_AGENT_PATTERN].flatten

  FISHTAGGER_APP_USER_AGENT_PATTERN = /fishtagger/i
  
  protected
  
  def logged_in?
    user_signed_in?
  end
  
  def auth_url_for(provider, options = {})
    provider = provider.to_s.downcase
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
    !(request.user_agent =~ ANDROID_APP_USER_AGENT_PATTERN).nil?
  end
  
  def is_iphone_app?
    !(request.user_agent =~ IPHONE_APP_USER_AGENT_PATTERN).nil? ||
      !(request.user_agent =~ IPHONE_APP_USER_AGENT_PATTERN_2).nil?
  end
  
  def is_iphone_app_2?
    !(request.user_agent =~ IPHONE_APP_USER_AGENT_PATTERN_2).nil?
  end
  
  def is_mobile_app?
    is_android_app? || is_iphone_app?
  end

  # haml agreesively removes whitespace in ugly mode. This forces it to look the way you meant it to look
  def haml_pretty(&block)
    haml_ugly_was = Haml::Template.options[:ugly]
    Haml::Template.options[:ugly] = false
    yield
    Haml::Template.options[:ugly] = haml_ugly_was
  end
end
