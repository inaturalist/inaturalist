#config/initializers/omniauth.rb
require 'openid/store/filesystem'

ActionController::Dispatcher.middleware.use OmniAuth::Builder do #if you are using rails 2.3.x
#Rails.application.config.middleware.use OmniAuth::Builder do #comment out the above line and use this if you are using rails 3
  if INAT_CONFIG["twitter"]
    provider :twitter, INAT_CONFIG["twitter"]["key"] , INAT_CONFIG["twitter"]["secret"]
  end
  if INAT_CONFIG["facebook"]
    opts = {:scope => 'email,offline_access,publish_stream,user_location'}
    opts[:client_options] = {:ssl => {:ca_path => "/etc/ssl/certs"}} if File.exists?("/etc/ssl/certs")
    provider :facebook, INAT_CONFIG["facebook"]["app_id"], INAT_CONFIG["facebook"]["app_secret"], opts
  end
  #provider :linked_in, 'key', 'secret'
  provider :open_id,  OpenID::Store::Filesystem.new('/tmp')
end
# you will be able to access the above providers by the following url
# /auth/providername for example /auth/twitter /auth/facebook

ActionController::Dispatcher.middleware do #if you are using rails 2.3.x
  #Rails.application.config.middleware do #comment out the above line and use this if you are using rails 3
  use OmniAuth::Strategies::OpenID,  OpenID::Store::Filesystem.new('/tmp'), :name => "google",  :identifier => "https://www.google.com/accounts/o8/id"
  use OmniAuth::Strategies::OpenID,  OpenID::Store::Filesystem.new('/tmp'), :name => "yahoo",   :identifier => "https://me.yahoo.com"
  #use OmniAuth::Strategies::OpenID,  OpenID::Store::Filesystem.new('/tmp'), :name => "aol",     :identifier => "https://openid.aol.com"
  #use OmniAuth::Strategies::OpenID,  OpenID::Store::Filesystem.new('/tmp'), :name => "myspace", :identifier => "http://myspace.com"
end
# you won't be able to access the openid urls like /auth/google
# you will be able to access them through
# /auth/open_id?openid_url=https://www.google.com/accounts/o8/id
# /auth/open_id?openid_url=https://me.yahoo.com
