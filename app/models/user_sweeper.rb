# class UserSweeper < ActionController::Caching::Sweeper  
#   observe User
#   
#   def after_update(user)
#     expire_fragment(:controller => 'welcome', :action => 'header', :for => user.id, 
#       :version => ApplicationController::HEADER_VERSION,
#       :site_name => SITE_NAME)
#   end
# end
