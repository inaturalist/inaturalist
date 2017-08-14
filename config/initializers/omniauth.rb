Rails.application.config.middleware.use OmniAuth::Builder do
  require 'openid/store/filesystem'

  # Replicate some omniauth code to bend over backwards so we can accommodate
  # the fact that soundcloud only allows one callback URL, so we *must* send
  # requests to them with a matching redirect_uri regardless of protocol
  # Check out the original definition of full_host at 
  # https://github.com/omniauth/omniauth/blob/master/lib/omniauth/strategy.rb#L411
  OmniAuth.config.full_host = lambda do |env|
    request = Rack::Request.new( env )
    is_ssl =
      request.env['HTTPS'] == 'on' ||
        request.env['HTTP_X_FORWARDED_SSL'] == 'on' ||
        request.env['HTTP_X_FORWARDED_SCHEME'] == 'https' ||
        (request.env['HTTP_X_FORWARDED_PROTO'] && request.env['HTTP_X_FORWARDED_PROTO'].split(',')[0] == 'https') ||
        request.env['rack.url_scheme'] == 'https'
    if request.scheme && request.url.match( URI::ABS_URI )
      uri = URI.parse(request.url.gsub(/\?.*$/, ''))
      uri.path = ''
      uri.scheme = 'https' if is_ssl
      if env['omniauth.strategy'].is_a?(OmniAuth::Strategies::SoundCloud) 
        uri.scheme = 'http'
      end
      uri.to_s
    else ''
    end
  end

  if CONFIG.twitter
    provider :twitter, CONFIG.twitter.key , CONFIG.twitter.secret
  end
  if fb_cfg = CONFIG.facebook
    opts = {:scope => 'email,user_location,user_photos'}
    provider :facebook, fb_cfg["app_id"], fb_cfg["app_secret"], opts
  end

  if CONFIG.soundcloud
    opts = { scope: "non-expiring" }
    if File.exists?( "/etc/ssl/certs" )
      opts[:client_options] = { ssl: { ca_path: "/etc/ssl/certs" } }
    end
    provider :soundcloud, CONFIG.soundcloud.client_id, CONFIG.soundcloud.secret, opts
  end
  
  if CONFIG.flickr
    FLICKR_SETUP = lambda do |env|
      request = Rack::Request.new(env)
      scope = request.params['scope'] if ProviderAuthorization::ALLOWED_SCOPES.include?(request.params['scope'].to_s)
      scope ||= "read"
      env['omniauth.strategy'].options[:scope] = scope
      env['rack.session']["omniauth_flickr_scope"] = scope
    end
    provider :flickr, CONFIG.flickr.key, CONFIG.flickr.shared_secret, :setup => FLICKR_SETUP
  end
  provider :open_id, :store => OpenID::Store::Filesystem.new('/tmp')
  provider :open_id, :name => 'yahoo', :identifier => 'https://me.yahoo.com'

  if CONFIG.google
    opts = {
      :scope => "userinfo.email,userinfo.profile,plus.me,https://picasaweb.google.com/data/",
      :prompt => "consent",
      :access_type => "offline"
    }
    provider :google_oauth2, CONFIG.google.client_id, CONFIG.google.secret, opts
  end

end
