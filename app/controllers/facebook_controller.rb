class FacebookController < ApplicationController
  before_filter :return_here, :only => [:options]
  before_filter :login_required

  # This is the endpoint which allows a user to manager their facebook account
  # settings.  They use this endpoint after they have already gone through the
  # signup process.
  def options
    @album_cover_photos = if current_user.facebook_identity
      facebook_albums(current_user)[0..3] || []
    else
      []
    end
  rescue Koala::Facebook::APIError => e
    if e.message =~ /OAuthException/
      redirect_to ProviderAuthorization::AUTH_URLS['facebook']
    else
      logger.error "[Error #{Time.now}] Facebook connection failed, error ##{e.type} (#{e}):  #{e.message}"
      HoptoadNotifier.notify(e, :request => request, :session => session) # testing
      flash[:error] = "Ack! Something went horribly wrong, like a giant " + 
                       "squid ate your Facebook info.  You can contact us at " +
                       "help@inaturalist.org if you still can't get this " + 
                       "working.  Error: #{e.message}"
    end
  end

  # Return an HTML fragment containing a list of the user's fb albums
  def albums
    context = params[:context] || 'user'
    @friend_id = params[:friend_id]
    @friend_id = nil if @friend_id=='null'
    # if context is friends, but no friend id specified, we want to show the friend selector
    if (context=='friends' && @friend_id.nil?) 
      @friends = facebook_friends(current_user)
      render :partial => 'facebook/friends' and return
    end
    begin
      @albums = facebook_albums(current_user, @friend_id)
      if @friend_id
        friend_data = current_user.facebook_api.get_object(@friend_id)
        @friend_name = friend_data['first_name']
      end
    rescue Koala::Facebook::APIError => e
      raise e unless e.message =~ /OAuthException/
      @reauthorization_needed = true
      []
    end
    render :partial => 'facebook/albums'
  end

#  this is mapped in config/routes.rb
#  def photo_fields
#    redirect_to :action => "albums"
#  end

  # Return an HTML fragment containing photos in the album with the given fb native album id (i.e., params[:id])
  def album
    limit = (params[:limit] || 10).to_i
    offset = ((params[:page] || 1).to_i - 1) * limit
    @friend_id = params[:friend_id]
    if @friend_id
      friend_data = current_user.facebook_api.get_object(@friend_id)
      @friend_name = friend_data['first_name']
    end
    @photos = current_user.facebook_api.get_connections(params[:id], 'photos', 
        :limit => limit, :offset => offset).map do |fp|
      FacebookPhoto.new_from_api_response(fp)
    end
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

  def photo_invite
    if request.post?
      fb_photos = (params[:facebook_photos] || [])
      # params[:facebook_photos] looks like {"0" => ['fb_photo_id_1','fb_photo_id_2'],...} to accomodate multiple photo-selectors on the same page
      fb_photo_ids = (fb_photos.is_a?(Hash) && fb_photos.has_key?('0') ? fb_photos['0'] : [])
      render(:json => {"error" => "You need to select at least one photo!"}.to_json) and return if fb_photo_ids.empty?
      
      invite_params = {:taxon_id => params[:taxon_id], :project_id=>params[:project_id]}
      invite_params.delete_if { |k, v| v.nil? || v.empty? }
      fb_photo_ids.each{|fb_photo_id|
        invite_params[:facebook_photo_id] = fb_photo_id
        # invite_params should include '#{flickr || facebook}_photo_id' and whatever else you want to add
        # to the observation, e.g. taxon_id, project_id, etc
        current_user.facebook_api.put_comment(fb_photo_id, params[:comment].gsub("{{INVITE_LINK}}", fb_accept_invite_url(invite_params)))
      }
      render :text => 'ok' and return
    end
  end
  
  protected

  # returns an array of album data hashes like [{ 'name'=>'Safari Pics', 'cover_photo_src'=>(thumbnail_url) }, ...]
  # not terribly efficient, cause it makes an api call to get album data and separate calls for each album to get the url
  def facebook_albums(user, friend_id=nil)
    return [] unless user.facebook_api
    album_data = user.facebook_api.get_connections(friend_id || 'me','albums', :limit => 0)
    album_data.reject{|a| a['count'].nil? || a['count'] < 1}.map do |a|
      {
        'aid' => a['id'],
        'name' => a['name'],
        'photo_count' => a['count'],
        'cover_photo_src' => 
          "https://graph.facebook.com/#{a['cover_photo']}/picture?type=album&access_token=#{user.facebook_token}"
      }
    end
  rescue OpenSSL::SSL::SSLError, Timeout::Error => e
    Rails.logger.error "[ERROR #{Time.now}] #{e}"
    return []
  end

  def facebook_friends(user)
    return [] unless user.facebook_api
    friends_data = user.facebook_api.get_connections('me','friends').sort_by{|f| f['name']}
    return friends_data
  rescue OpenSSL::SSL::SSLError, Timeout::Error => e
    Rails.logger.error "[ERROR #{Time.now}] #{e}"
    return []
  end
  
end
