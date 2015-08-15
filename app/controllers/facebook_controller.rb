class FacebookController < ApplicationController
  before_filter :return_here, :only => [:options]
  before_filter :authenticate_user!, :except => [:index]

  def index
    response.headers.delete "X-Frame-Options"
    @headless = @footless = true
    unless params[:by].blank?
      @selected_user = User.find_by_id(params[:by])
      @selected_user ||= User.find_by_login(params[:by])
    end
  end

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
      Rails.logger.error "[Error #{Time.now}] Facebook connection failed, error ##{e.type} (#{e}):  #{e.message}"
      Airbrake.notify(e, :request => request, :session => session) # testing
      Logstasher.write_exception(e, request: request, session: session, user: current_user)
      flash[:error] = "Ack! Something went horribly wrong, like a giant " +
                       "squid ate your Facebook info.  You can contact us at " +
                       "#{CONFIG.help_email} if you still can't get this " +
                       "working.  Error: #{e.message}"
    end
  end

  def photo_fields
    @context = params[:context] || 'user'
    if current_user.facebook_identity.blank?
      return authorize
    elsif current_user.facebook_api.blank?
      @reauthorization_needed = true
      return authorize
    end
      
    if @context == 'groups'
      @groups = facebook_groups(current_user)
      render :partial => 'facebook/groups' and return
    elsif @context == 'friends'
      @friend_id = params[:object_id]
      @friend_id = nil if @friend_id == 'null' || @friend_id.blank?
      if @friend_id.blank?  # if context is friends, but no friend id specified, we want to show the friend selector
        @friends = facebook_friends(current_user)
        render :partial => 'facebook/friends' and return
      else
        @albums = facebook_albums(current_user, @friend_id)
        friend_data = current_user.facebook_api.get_object(@friend_id)
        @friend_name = friend_data['first_name']
        render :partial => 'facebook/albums'
      end
    else # assume @context == 'user'
      @albums = facebook_albums(current_user)
      render :partial => 'facebook/albums' and return
    end
  rescue Koala::Facebook::APIError => e
    raise e unless e.message =~ /OAuthException/
    @reauthorization_needed = true
    authorize
  end

  private
  def authorize
    @provider = 'facebook'
    uri = Addressable::URI.parse(request.referrer) # extracts params and puts them in the hash uri.query_values
    uri.query_values ||= {}
    uri.query_values = uri.query_values.merge({:source => @provider, :context => @context})
    session[:return_to] = uri.to_s 
    render(:partial => "photos/auth")
  end
  public

  # Return an HTML fragment containing photos in the album with the given fb native album id (i.e., params[:id])
  def album
    limit = (params[:limit] || 10).to_i
    offset = ((params[:page] || 1).to_i - 1) * limit
    @friend_id = params[:object_id] unless (params[:object_id] == 'null' || params[:object_id].blank?)
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

  # Return an HTML fragment containing photos from the group's feed 
  # facebook group id should be specified as params[:object_id]
  def group
    limit = (params[:limit] || 10).to_i
    page = (params[:page] || 1).to_i
    @group_id = params[:object_id] unless params[:object_id]=='null'
    @photos = FacebookPhoto.fetch_from_fb_group(@group_id, current_user, {:limit => limit, :page => page})
    respond_to do |format|
      format.html do
        render :partial => 'photos/photo_list_form', 
               :locals => {
                 :photos => @photos, 
                 :index => params[:index],
                 :synclink_base => nil, 
                 :local_photos => false
               }
      end
    end
  end
  protected

  # returns an array of album data hashes like [{ 'name'=>'Safari Pics', 'cover_photo_src'=>(thumbnail_url) }, ...]
  # not terribly efficient, cause it makes an api call to get album data and separate calls for each album to get the url
  def facebook_albums(user, friend_id=nil)
    return [] unless user.facebook_api
    album_data = user.facebook_api.get_connections(friend_id || 'me', 'albums', :limit => 500)
    album_data.reject{|a| a['count'].blank? || a['count'] < 1}.map do |a|
      {
        'aid' => a['id'],
        'name' => a['name'],
        'photo_count' => a['count'],
        'cover_photo_src' => 
          "https://graph.facebook.com/#{a['cover_photo']}/picture?type=album&access_token=#{user.facebook_token}"
      }
    end
  rescue OpenSSL::SSL::SSLError, Timeout::Error, Errno::ENETUNREACH => e
    Rails.logger.error "[ERROR #{Time.now}] #{e}"
    return []
  end

  def facebook_friends(user)
    return [] unless user.facebook_api
    friends_data = user.facebook_api.get_connections('me','friends').sort_by{|f| f['name']}
    return friends_data
  rescue OpenSSL::SSL::SSLError, Timeout::Error, Errno::ENETUNREACH => e
    Rails.logger.error "[ERROR #{Time.now}] #{e}"
    return []
  end

  def facebook_groups(user)
    return [] unless user.facebook_api
    groups_data = user.facebook_api.get_connections('me','groups').sort_by{|f| f['name']}
    return groups_data
  rescue OpenSSL::SSL::SSLError, Timeout::Error, Errno::ENETUNREACH => e
    Rails.logger.error "[ERROR #{Time.now}] #{e}"
    return []
  end
  
end
