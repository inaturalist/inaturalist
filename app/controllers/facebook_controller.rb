class FacebookController < ApplicationController
  before_filter :return_here, :only => [:options]

  # This is the endpoint which allows a user to manager their facebook account
  # settings.  They use this endpoint after they have already gone through the
  # signup process.
  def options
    begin
      @album_cover_photos = @user.facebook_album_cover_photos[0..5]
#      unless @user.flickr_identity
#        @flickr_url = @flickr.auth.url_webapp(:write)
#      else
#        @photos = @flickr.photos.search(:user_id => @user.flickr_identity.flickr_user_id, :per_page => 6)
#      end
    rescue Net::Flickr::APIError => e
      logger.error "[Error #{Time.now}] Flickr connection failed (#{e}): #{e.message}"
      HoptoadNotifier.notify(e, :request => request, :session => session) # testing
      flash[:notice] = "Ack! Something went horribly wrong, like a giant " + 
                       "squid ate your Flickr info.  You can contact us at " +
                       "help@inaturalist.org if you still can't get this " + 
                       "working.  Error: #{e.message}"
    end
  end
  
end
