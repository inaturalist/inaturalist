Rails.application.config.middleware.use OmniAuth::Builder do
  require 'openid/store/filesystem' 
  if CONFIG.get(:twitter)
    provider :twitter, CONFIG.get(:twitter, :key) , CONFIG.get(:twitter, :secret)
  end
  if fb_cfg = CONFIG.get(:facebook)
    opts = {:scope => 'email,offline_access,publish_stream,user_location,user_photos,friends_photos,user_groups,read_stream'}
    opts[:client_options] = {:ssl => {:ca_path => "/etc/ssl/certs"}} if File.exists?("/etc/ssl/certs")
    provider :facebook, fb_cfg["app_id"], fb_cfg["app_secret"], opts
  end
  
  if CONFIG.get(:flickr)
    FLICKR_SETUP = lambda do |env|
      request = Rack::Request.new(env)
      scope = request.params['scope'] if ProviderAuthorization::ALLOWED_SCOPES.include?(request.params['scope'].to_s)
      scope ||= "read"
      env['omniauth.strategy'].options[:scope] = scope
      env['rack.session']["omniauth_flickr_scope"] = scope
    end
    provider :flickr, FLICKR_API_KEY, FLICKR_SHARED_SECRET, :setup => FLICKR_SETUP
  end
  provider :open_id, :store => OpenID::Store::Filesystem.new('/tmp')
  provider :open_id, :name => 'google', :identifier => 'https://www.google.com/accounts/o8/id'
  provider :open_id, :name => 'yahoo', :identifier => 'https://me.yahoo.com'
end
