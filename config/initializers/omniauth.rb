# Monkeypatch to add OmniAuth.providers array that lists all the strategies that
# are actually in use, not just the ones that are available
module OmniAuth
  @@providers = []
  mattr_accessor :providers

  class Builder < ::Rack::Builder
    def provider_patch(klass, *args, &block)
      OmniAuth.providers << klass
      old_provider(klass, *args, &block)
    end
    alias old_provider provider
    alias provider provider_patch
  end
end

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
    # Facebook requires app approval for the user_photos scope, and we're still
    # pending as of 20201110
    # opts = { scope: "email,user_photos", image_size: "large" }
    opts = {
      scope: "email",
      client_options: {
        site: 'https://graph.facebook.com/v10.0',
        authorize_url: "https://www.facebook.com/v10.0/dialog/oauth"
      }
    }
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
      # Apparently this just triggers scary permissions errors until we're a "verified" app on Google
      # :scope => "userinfo.email,userinfo.profile,plus.me,https://picasaweb.google.com/data/,https://www.googleapis.com/auth/photoslibrary.readonly",
      :scope => "userinfo.email,userinfo.profile,plus.me,https://www.googleapis.com/auth/photoslibrary.readonly",
      :prompt => "consent",
      :access_type => "offline"
    }
    provider :google_oauth2, CONFIG.google.client_id, CONFIG.google.secret, opts
  end

  if CONFIG.orcid
    provider :orcid, CONFIG.orcid.client_id, CONFIG.orcid.client_secret
  end

  if CONFIG.apple
    provider :apple, CONFIG.apple.client_id, "", {
      scope: "email name",
      team_id: CONFIG.apple.team_id,
      key_id: CONFIG.apple.key_id,
      pem: CONFIG.apple.pem,
      provider_ignores_state: true
    }
  end

end
