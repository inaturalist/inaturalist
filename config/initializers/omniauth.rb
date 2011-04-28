#config/initializers/omniauth.rb
require 'openid/store/filesystem'

ActionController::Dispatcher.middleware.use OmniAuth::Builder do #if you are using rails 2.3.x
#Rails.application.config.middleware.use OmniAuth::Builder do #comment out the above line and use this if you are using rails 3
  provider :twitter,  'D2yHhm9M053oTUc8qnxsg', '9YuBqljlpiPcGcgudczh5PWNvpce52mymGMkVzTVNvc'
  #provider :twitter,  'key', 'secret'
  provider :facebook, '2338988154', '7c068322856eddd9cfcba518d666ecca', :scope => 'email,offline_access' 
  #provider :linked_in, 'key', 'secret'
  #provider :open_id,  OpenID::Store::Filesystem.new('/tmp')
end
# you will be able to access the above providers by the following url
# /auth/providername for example /auth/twitter /auth/facebook

ActionController::Dispatcher.middleware do #if you are using rails 2.3.x
  #Rails.application.config.middleware do #comment out the above line and use this if you are using rails 3
  #use OmniAuth::Strategies::OpenID,  OpenID::Store::Filesystem.new('/tmp'), :name => "google",  :identifier => "https://www.google.com/accounts/o8/id"
  #use OmniAuth::Strategies::OpenID,  OpenID::Store::Filesystem.new('/tmp'), :name => "yahoo",   :identifier => "https://me.yahoo.com"
  #use OmniAuth::Strategies::OpenID,  OpenID::Store::Filesystem.new('/tmp'), :name => "aol",     :identifier => "https://openid.aol.com"
  #use OmniAuth::Strategies::OpenID,  OpenID::Store::Filesystem.new('/tmp'), :name => "myspace", :identifier => "http://myspace.com"
end
# you won't be able to access the openid urls like /auth/google
# you will be able to access them through
# /auth/open_id?openid_url=https://www.google.com/accounts/o8/id
# /auth/open_id?openid_url=https://me.yahoo.com
