class FacebookController < ApplicationController
  before_filter :return_here, :only => [:options]

  # This is the endpoint which allows a user to manager their facebook account
  # settings.  They use this endpoint after they have already gone through the
  # signup process.
  def options
    begin
      #@album_cover_photos = @user.facebook_album_cover_photos[0..5]
      @album_cover_photos = @user.facebook_albums[0..3]
    rescue Koala::Facebook::APIError => e
      logger.error "[Error #{Time.now}] Facebok connection failed, error ##{e.type} (#{e}):  #{e.message}"
      HoptoadNotifier.notify(e, :request => request, :session => session) # testing
      flash[:notice] = "Ack! Something went horribly wrong, like a giant " + 
                       "squid ate your Facebook info.  You can contact us at " +
                       "help@inaturalist.org if you still can't get this " + 
                       "working.  Error: #{e.message}"
    end
  end

  # Return an HTML fragment containing a list of the user's fb albums
  def albums
    @albums = @user.facebook_albums
    render(:partial => 'facebook/albums')
  end

#  this is mapped in config/routes.rb
#  def photo_fields
#    redirect_to :action => "albums"
#  end

  # Return an HTML fragment containing photos in the album with the given fb native album id (i.e., params[:id])
  def album
    per_page = (params[:limit] || 10).to_i
    page = (params[:page] || 1).to_i
    from = ((page-1)*per_page)
    to = ((page*per_page)-1)
    all_photos = @user.facebook_album_photos(params[:id])
    @photos = (all_photos[from..to] || []).map{|fp| FacebookPhoto.new_from_api_response(fp)}
    # sync doesn't work with facebook! they strip exif metadata from photos. :(
    #@synclink_base = params[:synclink_base] unless params[:synclink_base].blank?
    respond_to do |format|
      format.html do
        render :partial => 'photos/photo_list_form', 
               :locals => {
                 :photos => @photos, 
                 :index => params[:index],
                 :synclink_base => nil, #@synclink_base,
                 :local_photos => false,
                 :organized_by_album => true
               }
      end
    end
  end
  
end
