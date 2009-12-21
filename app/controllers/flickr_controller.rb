class FlickrController < ApplicationController
  before_filter :login_required  
  before_filter :ensure_has_no_flickr_identity,
                :only => ['link']
  
  # This is where Flickr sends the user back to after authorizing their
  # account.  Note that there should not be a view associated with this end-
  # point.  It simply takes the token along with some other data and creates
  # a new FlickrIdentity.
  def authorize
    if params[:frob].nil?
      redirect_to :action => 'options' and return
    end
    
    begin
      @flickr = get_net_flickr
      
      # Strangely, if an auth token has already been set, net-flickr will try 
      # to append it to the getToken call, which makes Flickr unhappy.  So we
      # reset it.
      @flickr.auth.token = nil
      @flickr.auth.get_token(params[:frob])
      
      if @flickr_identity = current_user.flickr_identity
        @flickr_identity.token = @flickr.auth.token
        @flickr_identity.token_created_at = Time.now
      else
        @flickr_identity = FlickrIdentity.new(
          :user => current_user,
          :token => @flickr.auth.token,
          :token_created_at => Time.now,
          :flickr_username => @flickr.auth.user_name,
          :flickr_user_id => @flickr.auth.user_id
        )
      end
      
      if @flickr_identity.save
        # This redirects to the 'success' page if the user has justed signed
        # up to iNaturalist and has linked their flickr accounts.
        if @user.created_at > 5.minutes.ago
          redirect_to :action => 'success' and return
        else
          if @flickr_identity.created_at > 5.minutes.ago
            flash[:notice] = <<-EOF
              Great Success! We linked your Flickr account to your iNaturalist
              account.
            EOF
          else
            flash[:notice] = <<-EOF
              Cool, your linked Flickr account has been updated.
            EOF
          end
          redirect_to :action => 'options' and return
        end
      else
        logger.error "[ERROR] Failed to save a new flickr identity: " +
          @flickr_identity.errors.full_messages.join(', ')
      end
    rescue Net::Flickr::APIError => e
      flash[:error] = <<-EOF
        Ack! Something went wrong linking your iNaturalist account to Flickr.
        Try it again, or contact us at help@inaturalist.org.
        
        Error: #{e.message}
      EOF
      redirect_to :action => 'options'
    end
  end
  
  # This is the endpoint the user visits to link their iNaturalist account to
  # their Flickr account directly after signup. Luckly we don't have to manage a
  # whole lot from Flickr, they either have an account or don't, and Flickr
  # handles the process of creating Flickr accounts and then authorizing the
  # user.
  def link
    perms = params[:perms] || :write
    @flickr = get_net_flickr
    @flickr_url = @flickr.auth.url_webapp(perms)
  end
  
  # A cheesy endpoint that is only accessed after the user has successfully
  # linked their flickr account after signup.  It asks if the user would like
  # to auto import from their Flickr account into their iNaturalist account,
  # and then handles that simple form
  def success
    redirect_to(:action => 'options') and return if @user.flickr_identity.nil?
    begin
      unless !params[:flickr_identity].nil?
        @person = get_net_flickr.people.find_by_username(@user.flickr_identity.flickr_username)
        @photos = @person.photos({'per_page' => 5})
      else
        unless @user.flickr_identity.update_attributes(params[:flickr_identity])
          flash[:notice] = "Oh my! We messed up somewhere and couldn't " + 
                           "turn on auto importing.  Try again in a bit, " + 
                           "hopefully we'll have this figured out."
        end
        redirect_to :controller => :observations, :action => @user.login
      end
    rescue Net::Flickr::APIError => e
      flash[:notice] = "Ack! Something went horribly wrong, like a giant " + 
                       "squid ate your Flickr info.  You can contact us at " + 
                       "help@inaturalist.org if you still can't get this " + 
                       "working.  Error: #{e.message}"
      redirect_to :action => 'options'
    end
  end
  
  # Finds photos for the logged-in user
  def photos
    @flickr = get_net_flickr
    @flickr.auth.token = @user.flickr_identity.token
    params[:limit] ||= 10
    params[:page] ||= 1
    unless params[:q]
      @photos = @flickr.photos.get_public_photos(
        @user.flickr_identity.flickr_user_id, 
        {'per_page' => params[:limit], 'page' => params[:page]})
    else
      # Try to look up a photo id
      if params[:q].to_i != 0 && params[:q].to_i > 10000
        @photos = [@flickr.photos.get_info(params[:q])].compact
      else
        @photos = @flickr.photos.search({
          'user_id' => @user.flickr_identity.flickr_user_id, 
          'text' => "#{params[:q]}",
          'per_page' => params[:limit],
          'page' => params[:page]}).map do |fp|
          FlickrPhoto.new_from_net_flickr(fp)
        end
      end
    end
    respond_to do |format|
      format.html
      format.js   { 
        @i = params[:i] || 1
        render }
      format.json { render :json => @photos.to_json }
    end
  end
  
  # Return an HTML fragment containing checkbox inputs for Flickr photos.
  # Params:
  #   q:        query string
  #   context:  Set to 'user' to search only the logged in user's photos. 
  #             Otherwise search all CC'd photos.
  #   index:    index to use if these inputs are part of a form subcomponent
  #             (makes names like flickr_photos[:index][])
  def photo_fields
    @flickr = get_net_flickr
    search_params = {}
    
    # If this is for a user, set the auth token
    case params[:context]
    when 'user'
      @flickr.auth.token = current_user.flickr_identity.token
      search_params['user_id'] = @user.flickr_identity.flickr_user_id
      
    # Otherwise, make sure we're only searching CC'd photos
    else
      search_params['license'] = '1,2,3,4,5,6'
    end

    
    # Try to look up a photo id
    @photos = []
    if params[:q].to_i != 0 && params[:q].to_i > 10000
      if fp = @flickr.photos.get_info(params[:q])
        if params[:context] == 'user' && 
            fp.owner == current_user.flickr_identity.flickr_user_id
          @photos = [fp]
        end
      end
    else
      search_params['per_page'] = params[:limit] ||= 10
      search_params['text'] = params[:q]
      search_params['page'] = params[:page] ||= 1
      search_params['extras'] = 'date_upload,owner_name'
      search_params['sort'] = 'relevance'
      @photos = @flickr.photos.search(search_params)
    end
    
    # Determine whether we should include synclinks
    @synclink_base = params[:synclink_base] unless params[:synclink_base].blank?
    
    # TODO: Lookup matching flickr_photo objects
    # @matching_flickr_photos = case params[:context]
    #   when 'user'
    #     FlickrPhoto.all(:include => :observations, 
    #       :conditions => ["observations.user_id = ?", current_user.id])
    #   else
    #     FlickrPhoto.all(:conditions => ["flickr_native_photo_id IN (?)", 
    #       @photos.map(&:id)])
    #   end
    
    respond_to do |format|
      format.html do
        render :partial => 'photo_list_form', 
               :locals => {
                 :photos => @photos, 
                 :index => params[:index],
                 :synclink_base => @synclink_base
               }
      end
    end
  end
  
  # This is the endpoint which allows a user to manager their flickr account
  # settings.  They use this endpoint after they have already gone through the
  # signup process.
  def options
    begin
      unless @user.flickr_identity
        @flickr = get_net_flickr
        @flickr_url = @flickr.auth.url_webapp(:write)
      else
        @person = get_net_flickr.people.find_by_username(@user.flickr_identity.flickr_username)
        @photos = @person.photos({'per_page' => 5})
      end
    rescue Net::Flickr::APIError => e
      flash[:notice] = "Ack! Something went horribly wrong, like a giant " + 
                       "squid ate your Flickr info.  You can contact us at " +
                       "help@inaturalist.org if you still can't get this " + 
                       "working.  Error: #{e.message}"
    end
  end
  
  # Used by the options interface, this just removes the user's associated
  # flickr_identity
  def unlink_flickr_account
    if @user.flickr_identity
      @user.flickr_identity.destroy
      flash[:notice] = "We've dissassociated your Flickr account from your iNaturalist account."
      redirect_to :action => 'options'
    else
      flash[:notice] = "Your Flickr account has not been linked before!"
      redirect_to :action => 'options'
    end
  end
  
  def add_tags
    get_flickraw
    begin
      photo_id = params[:photo_id] || params[:id]
      flickr.photos.addTags(
        :auth_token => current_user.flickr_identity.token, 
        :photo_id => photo_id,
        :tags => params[:tags]
      )
    rescue Exception => e
      @error = e
    end
    
    respond_to do |format|
      format.json do
        unless @error
          photo = flickr.photos.getInfo(:photo_id => photo_id)
          render :status => 200, :json => photo.tags
        else
          render :status => :unprocessable_entity, :json => @error.to_json
        end
      end
    end
  end
  
  # Delete a tag from a Flickr photo using the current users auth
  def remove_tag
    get_flickraw
    begin
      flickr.photos.removeTag(:auth_token => current_user.flickr_identity.token, 
        :tag_id => params[:tag_id] || params[:id])
    rescue Exception => e
      @error = e
    end
    
    respond_to do |format|
      format.json do
        unless @error
          render :status => 200, :json => "Tag removed."
        else
          render :status => :unprocessable_entity, :json => @error
        end
      end
    end
  end
  
  private
  def ensure_has_no_flickr_identity
    redirect_to(:action => 'options') and return if current_user.flickr_identity
  end

end
