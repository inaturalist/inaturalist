module Ambidextrous
  IPHONE_APP_USER_AGENT_PATTERN_1 = /Titanium/i
  IPHONE_APP_USER_AGENT_PATTERN_2 = /^iNaturalist\/\d+.+iOS/i
  IPHONE_APP_USER_AGENT_PATTERN = /#{IPHONE_APP_USER_AGENT_PATTERN_1}|#{IPHONE_APP_USER_AGENT_PATTERN_2}/
  IPHONE_APP_USER_AGENT_PATTERNS = [IPHONE_APP_USER_AGENT_PATTERN, IPHONE_APP_USER_AGENT_PATTERN_2]
  ANDROID_APP_USER_AGENT_PATTERN = /^iNaturalist\/\d+.+Android/i
  INATRN_APP_USER_AGENT_PATTERN = /^iNaturalistRN/
  MOBILE_APP_USER_AGENT_PATTERNS = [IPHONE_APP_USER_AGENT_PATTERNS, ANDROID_APP_USER_AGENT_PATTERN].flatten

  FISHTAGGER_APP_USER_AGENT_PATTERN = /fishtagger/i
  
  protected
  
  def logged_in?
    user_signed_in?
  end
  
  def auth_url_for(provider, options = {})
    provider = provider.to_s.downcase
    provider = 'google_oauth2' if provider == 'picasa'
    url = ProviderAuthorization::AUTH_URLS[provider]
    url += "?" + options.map{|k,v| "#{k}=#{v}"}.join('&') unless options.blank?
    url
  end

  def is_inaturalistjs_request?
    request.headers["X-Via"] === "inaturalistjs" ||
      request.headers["X-Via"] === "node-api"
  end

  def is_android_app?
    return false if is_inaturalistjs_request?
    !(request.user_agent =~ ANDROID_APP_USER_AGENT_PATTERN).nil?
  end

  def is_iphone_app?
    return false if is_inaturalistjs_request?
    !(request.user_agent =~ IPHONE_APP_USER_AGENT_PATTERN).nil? ||
      !(request.user_agent =~ IPHONE_APP_USER_AGENT_PATTERN_2).nil?
  end

  def is_iphone_app_2?
    return false if is_inaturalistjs_request?
    !(request.user_agent =~ IPHONE_APP_USER_AGENT_PATTERN_2).nil?
  end

  def is_inatrn_app?
    return false if is_inaturalistjs_request?

    !( request.user_agent =~ INATRN_APP_USER_AGENT_PATTERN ).nil?
  end

  def is_mobile_app?
    return false if is_inaturalistjs_request?

    is_android_app? || is_iphone_app? || is_inatrn_app?
  end

  # haml agreesively removes whitespace in ugly mode. This forces it to look the way you meant it to look
  def haml_pretty(&block)
    haml_ugly_was = Haml::Template.options[:ugly]
    Haml::Template.options[:ugly] = false
    yield
    Haml::Template.options[:ugly] = haml_ugly_was
  end

  #
  # Filter to set a return url
  #
  def return_here
    ie_needs_return_to = false
    if request.user_agent =~ /msie/i && params[:format].blank? && 
        ![Mime[:js], Mime[:json], Mime[:xml], Mime[:kml], Mime[:atom]].map(&:to_s).include?(request.format.to_s)
      ie_needs_return_to = true
    end
    if (ie_needs_return_to || request.format.blank? || request.format.html?) && !params.keys.include?('partial')
      session[:return_to] = request.fullpath
    end
    true
  end
end
