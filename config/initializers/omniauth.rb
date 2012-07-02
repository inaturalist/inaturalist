Rails.application.config.middleware.use OmniAuth::Builder do
  require 'openid/store/filesystem' 
  if INAT_CONFIG["twitter"]
    provider :twitter, INAT_CONFIG["twitter"]["key"] , INAT_CONFIG["twitter"]["secret"]
  end
  if fb_cfg = INAT_CONFIG["facebook"]
    opts = {:scope => 'email,offline_access,publish_stream,user_location,user_photos,friends_photos,user_groups,read_stream'}
    opts[:client_options] = {:ssl => {:ca_path => "/etc/ssl/certs"}} if File.exists?("/etc/ssl/certs")
    provider :facebook, fb_cfg["app_id"], fb_cfg["app_secret"], opts
  end
  provider :flickr, FLICKR_API_KEY, FLICKR_SHARED_SECRET if INAT_CONFIG["flickr"]
  provider :open_id, :store => OpenID::Store::Filesystem.new('/tmp')
  provider :open_id, :name => 'google', :identifier => 'https://www.google.com/accounts/o8/id'
  provider :open_id, :name => 'yahoo', :identifier => 'https://me.yahoo.com'
end
