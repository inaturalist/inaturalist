module Ambidextrous
  IPHONE_APP_USER_AGENT_PATTERN_2 = /^iNaturalist\/\d+.+iOS/i

  ANDROID_APP_USER_AGENT_REGEX_PATTERNS = [
    "(iNaturalist)/([0-9.]+) \\(Build [0-9]+; Android"
  ]
  IPHONE_APP_USER_AGENT_REGEX_PATTERNS = [
    "(iNaturalist)/([0-9]+) CFNetwork",
    "(iNaturalist)/([0-9.]+) \\(iOS",
    "(iNaturalist)/([0-9.]+) \\(iPad",
    "(iNaturalist)/([0-9.]+) \\(iPhone"
  ]
  REACT_APP_USER_AGENT_REGEX_PATTERNS = [
    "(iNaturalistRN)/([0-9.]+) \\(Build",
    "(iNaturalistRN)/([0-9.]+) Handset",
    "(iNaturalistReactNative)/([0-9.]+)"
  ]

  def is_android_user_agent?
    return false if user_agent.nil?

    ANDROID_APP_USER_AGENT_REGEX_PATTERNS.any? do | pattern |
      request.user_agent =~ /#{pattern}/
    end
  end

  def is_iphone_user_agent?
    return false if user_agent.nil?

    IPHONE_APP_USER_AGENT_REGEX_PATTERNS.any? do | pattern |
      request.user_agent =~ /#{pattern}/
    end
  end

  def is_inatrn_user_agent?
    return false if user_agent.nil?

    REACT_APP_USER_AGENT_REGEX_PATTERNS.any? do | pattern |
      request.user_agent =~ /#{pattern}/
    end
  end

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

    is_android_user_agent?( request.user_agent )
  end

  def is_iphone_app?
    return false if is_inaturalistjs_request?

    is_iphone_user_agent?( request.user_agent )
  end

  def is_iphone_app_2?
    return false if is_inaturalistjs_request?
    !(request.user_agent =~ IPHONE_APP_USER_AGENT_PATTERN_2).nil?
  end

  def is_inatrn_app?
    return false if is_inaturalistjs_request?

    is_inatrn_user_agent?( request.user_agent )
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
