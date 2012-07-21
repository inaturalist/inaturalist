class PicasaController < ApplicationController
  before_filter :login_required
  verify :method => :delete, :only => "unlink"
  
  # Configure Picasa linkage
  def options
    if @picasa_identity = current_user.picasa_identity
      @picasa = Picasa.new(@picasa_identity.token)
      @picasa_photos = @picasa.recent_photos(@picasa_identity.picasa_user_id, 
        :max_results => 18, :thumbsize => '72c').entries
    else
      @auth_url = Picasa.authorization_url(url_for(:action => "authorize"))
    end
  end
  
  # Receives redirect from Google after initial auth
  def authorize
    begin
      @picasa = Picasa.authorize_request(self.request)
    rescue RubyPicasa::PicasaTokenError => e
      flash[:error] = "Picasa authorization failed!"
      Rails.logger.error "[ERROR] Picasa authorization failed: #{e}"
      return redirect_to :action => "options"
    end
    
    @picasa_identity = PicasaIdentity.find_or_initialize_by_user_id(current_user.id)
    @picasa_identity.token = @picasa.token
    @picasa_user = @picasa.user('default')
    if @picasa_user.respond_to?(:user)
      @picasa_identity.picasa_user_id = @picasa_user.user
    elsif @picasa_user.respond_to?(:photos)
      @picasa_identity.picasa_user_id = @picasa_user.photos.first.try(:user)
    end
    
    # trying to work out a bug here...
    if @picasa_identity.picasa_user_id.blank?
      Rails.logger.error "[ERROR #{Time.now}] Failed to extract Picasa user ID, trying again with debugging on..."
      @picasa.debug = true
      
      @picasa_user = @picasa.user('default')
      if @picasa_user.respond_to?(:user)
        @picasa_identity.picasa_user_id = @picasa_user.user
      elsif @picasa_user.respond_to?(:photos)
        @picasa_identity.picasa_user_id = @picasa_user.photos.first.try(:user)
      end
      
      if @picasa_identity.picasa_user_id.blank?
        flash[:error] = "Picasa authorization worked, but we couldn't find " + 
          "your Picasa user ID. The issue has been reported, so we'll look " + 
          "into it. In the meantime, you might try uploading photos " + 
          "directly, or linking your Flickr or Facebook accounts."
        HoptoadNotifier.notify(
          Exception.new("Failed to extract Picasa user ID from user response (#{@picasa_user})"), 
          :request => request, :session => session)
        redirect_to :action => "options"
        return
      end
    end
    
    @picasa_identity.save
    
    flash[:notice] = "Congrats, your iNaturalist and Picasa accunts have been linked!"
    if !session[:return_to].blank?
      @landing_path = session[:return_to]
      session[:return_to] = nil
    end
    redirect_to (@landing_path || {:action => "options"})
  end
  
  # Offer user option to unlink iNat & Picasa accounts
  def unlink
    if current_user.picasa_identity
      current_user.picasa_identity.destroy
      flash[:notice] = "We've dissassociated your Picasa account from your iNaturalist account."
      redirect_to :action => 'options'
    else
      flash[:notice] = "Your Picasa account has not been linked before!"
      redirect_to :action => 'options'
    end
  end
  
  def photo_fields
    context = params[:context] || 'user'
    pi = current_user.picasa_identity
    if pi.nil?
      @provider = 'picasa'
      uri = Addressable::URI.parse(request.referrer) # extracts params and puts them in the hash uri.query_values
      uri.query_values ||= {}
      uri.query_values = uri.query_values.merge({:source => @provider, :context => context})
      @auth_url = Picasa.authorization_url(url_for(:action => "authorize"))
      session[:return_to] = uri.to_s 
      render(:partial => "photos/auth") and return
    end
    #picasa_client = GData::Client::Photos.new
    #picasa_client.authsub_token = pi.token
    @albums = picasa_albums(current_user)
=begin
    #if context=='user'
      album_data = picasa_client.get("https://picasaweb.google.com/data/feed/api/user/#{pi.picasa_user_id}").to_xml
      @albums = []
      album_data.elements.each('entry'){|a|
        @albums << {
          'aid' => a.elements['gphoto:id'].text, 
          'name' => a.elements['title'].text,
          'cover_photo_src' => a.elements['media:group'].elements['media:thumbnail'].attributes['url']
        }
      }
=end
      #@albums = picasa_albums(current_user)
      render :partial => 'picasa/albums' and return
    #end

  end

  # Return an HTML fragment containing photos in the album with the given fb native album id (i.e., params[:id])
  def album
    #limit = (params[:limit] || 10).to_i
    #offset = ((params[:page] || 1).to_i - 1) * limit
    @friend_id = params[:object_id] unless params[:object_id]=='null'
    if @friend_id
      friend_data = current_user.facebook_api.get_object(@friend_id)
      @friend_name = friend_data['first_name']
    end
    per_page = params[:limit] ? params[:limit].to_i : 10
    search_params = {
      :max_results => per_page,
      :start_index => ((params[:page] || 1).to_i * per_page - per_page + 1),
      :picasa_user_id => @friend_id
    }
    @photos = PicasaPhoto.get_photos_from_album(current_user, params[:id], search_params) 
=begin
    @photos = current_user.facebook_api.get_connections(params[:id], 'photos', 
        :limit => limit, :offset => offset).map do |fp|
      FacebookPhoto.new_from_api_response(fp)
    end
=end
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

  def old_photo_fields
    token = if logged_in? && current_user.picasa_identity
      current_user.picasa_identity.token
    else
      nil
    end
    picasa = Picasa.new(token)
    search_params = {}
    
    # If this is for a user, set the auth token
    case params[:context]
    when 'user'
      search_params[:user_id] = current_user.picasa_identity.picasa_user_id
      
    # Otherwise, make sure we're only searching CC'd photos
    else
      # search_params['license'] = '1,2,3,4,5,6'
      # Picasa doesn't allow CC filtering through its API yet...
      return
    end
    
    per_page = params[:limit] ? params[:limit].to_i : 10
    search_params[:max_results] = per_page
    search_params[:start_index] = (params[:page] || 1).to_i * per_page - per_page + 1
    search_params[:thumbsize] = RubyPicasa::Photo::VALID.join(',')
    
    if results = picasa.search(params[:q], search_params)
      @photos = results.photos.map do |api_response|
        next unless api_response.is_a?(RubyPicasa::Photo)
        PicasaPhoto.new_from_api_response(api_response, :user => current_user)
      end.compact
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

  protected 

=begin
  def picasa_albums(user, picasa_user_id=nil)
    return [] unless user.picasa_identity
    picasa_client = user.picasa_api
    picasa_uid = (picasa_user_id || user.picasa_identity.picasa_user_id)
    album_data = picasa_client.get("https://picasaweb.google.com/data/feed/api/user/#{picasa_uid}").to_xml
    albums = []
    album_data.elements.each('entry'){|a|
      albums << {
        'aid' => a.elements['gphoto:id'].text, 
        'name' => a.elements['title'].text,
        'cover_photo_src' => a.elements['media:group'].elements['media:thumbnail'].attributes['url']
      }
    }
    return albums
  end
=end

  def picasa_albums(user, picasa_user_id=nil)
    return [] unless user.picasa_identity
    picasa = user.picasa_client #Picasa.new(user.picasa_identity.token)
    user_data = picasa.user(picasa_user_id) 
    albums = []
    user_data.albums.reject{|a| a.numphotos==0}.each{|a|
      albums << {
        'aid' => a.id,
        'name' => a.title,
        'cover_photo_src' => a.photos.first.url
      }
    }
    return albums
  end

end
