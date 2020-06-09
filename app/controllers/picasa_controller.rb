class PicasaController < ApplicationController
  before_filter :authenticate_user!
  
  # Configure Picasa linkage
  def options
    if @provider_authorization = current_user.has_provider_auth('google')
      @picasa_photos = begin
        PicasaPhoto.picasa_request_with_refresh(current_user.picasa_identity) do
          goog = GooglePhotosApi.new( current_user.picasa_identity.token )
          goog.media_items( pageSize: 24 )["mediaItems"].map{|mi| PicasaPhoto.new_from_api_response( mi ) }
        end
      rescue RestClient::Forbidden, RestClient::Unauthorized
        flash.now[:error] = "Failed to access your Google Photos. Try unlinking and re-linking your accounts."
        nil
      end
    end
  end
  
  def photo_fields
    context = params[:context] || 'user'
    pa = current_user.has_provider_auth('google')
    if pa.nil?
      @provider = 'picasa'
      uri = URI.parse( request.referrer ) # extracts params and puts them in the hash uri.query_values
      query_values ||= {}
      query_values = Rack::Utils.parse_nested_query( uri.query ).symbolize_keys.merge( source: @provider, context: context )
      uri.query = query_values.to_query
      @auth_url = ProviderAuthorization::AUTH_URLS['google']
      session[:return_to] = uri.to_s 
      render(:partial => "photos/auth") and return
    end
    if false
    # if context == 'user' && params[:q].blank? # search is blank, so show all albums
    #   @albums = picasa_albums(current_user)
    #   render :partial => 'picasa/albums' and return
    # elsif context == 'friends'
    #   @friend_id = params[:object_id]
    #   @friend_id = nil if @friend_id=='null'
    #   if @friend_id.nil?  # if context is friends, but no friend id specified, we want to show the friend selector
    #     @friends = picasa_friends(current_user)
    #     render :partial => 'picasa/friends' and return
    #   else
    #     @albums = picasa_albums(current_user, @friend_id)
    #     friend_data = current_user.picasa_client.user(@friend_id)
    #     @friend_name = friend_data.author.name 
    #     render :partial => 'picasa/albums' and return
    #   end
    else # context='public' or context='user' with a search query
      picasa = current_user.picasa_client
      search_params = {}
      per_page = params[:limit] ? params[:limit].to_i : 10
      if context == 'user'
        search_params[:user_id] = current_user.picasa_identity.provider_uid
      end
      begin
        Timeout::timeout(10) do
          @page_token = params[:page_token]
          results = PicasaPhoto.picasa_request_with_refresh(current_user.picasa_identity) do
            # picasa.search(params[:q], search_params)
            goog = GooglePhotosApi.new( current_user.picasa_identity.token )
            goog.search( pageSize: per_page, pageToken: @page_token )
          end
          if results
            @next_page_token = results["nextPageToken"]
            @photos = results["mediaItems"].map do |api_response|
              PicasaPhoto.new_from_api_response(api_response, :user => current_user)
            end.compact
          end
        end
      rescue Timeout::Error => e
        @timeout = e
      rescue RestClient::Forbidden
        @forbidden = true
      end
    end
    
    @synclink_base = params[:synclink_base] unless params[:synclink_base].blank?

    respond_to do |format|
      format.html do
        render :partial => 'photos/photo_list_form', 
               :locals => {
                 :photos => @photos, 
                 :index => params[:index],
                 :synclink_base => @synclink_base,
                 :local_photos => false
               }
      end
    end
  end

  # Return an HTML fragment containing photos in the album with the given fb native album id (i.e., params[:id])
  def album
    # @friend_id = params[:object_id] unless (params[:object_id] == 'null' || params[:object_id].blank?)
    # if @friend_id
    #   friend_data = current_user.picasa_client.user(@friend_id)
    #   @friend_name = friend_data.author.name 
    # end
    per_page = (params[:limit] ? params[:limit].to_i : 10)
    search_params = {
      albumId: params[:id],
      pageSize: per_page
    }
    if params[:page_token]
      search_params[:pageToken] = params[:page_token]
    end
    goog = GooglePhotosApi.new( current_user.picasa_identity.token )
    @photos = PicasaPhoto.picasa_request_with_refresh( current_user.picasa_identity ) do
      r = goog.search( search_params )
      @next_page_token = r["nextPageToken"]
      Rails.logger.debug "[DEBUG] r: #{r}"
      (r["mediaItems"] || []).map{|mi| PicasaPhoto.new_from_api_response( mi ) }
    end
    # @photos = PicasaPhoto.get_photos_from_album(current_user, params[:id], search_params) 
    @synclink_base = params[:synclink_base] unless params[:synclink_base].blank?
    respond_to do |format|
      format.html do
        render :partial => 'photos/photo_list_form', 
               :locals => {
                 :photos => @photos, 
                 :index => params[:index],
                 :synclink_base => nil, 
                 :local_photos => false,
                 :organized_by_album => true
               }
      end
    end
  end

  protected 

  # fetch picasa albums
  # user is used to authenticate the request
  # picasa_user_id specifies the picasa user whose albums to fetch
  # (if nil, it fetches the authenticating user's albums)
  def picasa_albums(options = {})
    return [] unless current_user.has_provider_auth('google')
    PicasaPhoto.picasa_request_with_refresh(current_user.picasa_identity) do
      goog = GooglePhotosApi.new( current_user.picasa_identity.token )
      goog.albums["albums"]
    end
  end

  def picasa_friends(user)
    return [] unless (pa = current_user.has_provider_auth('google'))
    picasa = GData::Client::Photos.new
    picasa.auth_token = pa.token
    contacts_data = picasa.get("http://picasaweb.google.com/data/feed/api/user/default/contacts").to_xml 
    friends = []
    contacts_data.elements.each('entry'){|e|
      friends << {
        'id' => e.elements['gphoto:user'].text, # this is a feed url that id's the photo
        'name' => e.elements['gphoto:nickname'].text,
        'pic_url' => e.elements['gphoto:thumbnail'].text
      }
    }
    friends
  end

end
