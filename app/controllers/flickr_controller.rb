class FlickrController < ApplicationController
  before_filter :authenticate_user! , :except => [:invite]
  before_filter :ensure_has_no_flickr_identity, :only => ['link']
  before_filter :return_here, :only => [:index, :show, :by_login, :options]
  
  # Finds photos for the logged-in user
  def photos
    f = get_flickraw
    params[:limit] ||= 10
    params[:page] ||= 1
    unless params[:q]
      @photos = f.photos.search(
        :user_id => current_user.flickr_identity.flickr_user_id, 
        :extras => 'url_s',
        'per_page' => params[:limit], 
        'page' => params[:page])
    else
      # Try to look up a photo id
      if params[:q].to_i != 0 && params[:q].to_i > 10000
        @photos = [f.photos.getInfo(:photo_id => params[:q])].compact
      else
        @photos = @flickr.photos.search(
            'user_id' => current_user.flickr_identity.flickr_user_id, 
            'text' => "#{params[:q]}",
            :extras => 'url_s',
            'per_page' => params[:limit],
            'page' => params[:page]).map do |fp|
          FlickrPhoto.new_from_api_response(fp)
        end
      end
    end
    respond_to do |format|
      format.html
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
    @flickr = get_flickraw
    if params[:licenses].blank?
      @license_numbers = [1,2,3,4,5,6].join(',')
    elsif params[:licenses] == 'any'
      @license_numbers = nil
    else
      @licenses = params[:licenses]
      @licenses = @licenses.split(',') if @licenses.is_a?(String)
      @license_numbers = @licenses.map {|code| Photo.license_number_for_code(code)}.join(',')
    end
    context = (params[:context] || 'public')
    flickr_pa = current_user.has_provider_auth('flickr')
    if params[:require_write] && flickr_pa.try(:scope) != 'write' # we need write permissions for flickr commenting
      @reauthorization_needed = true if flickr_pa
      @provider = 'flickr'
      @url_options = {:scope => 'write'}
      uri = Addressable::URI.parse(request.referrer) # extracts params and puts them in the hash uri.query_values
      uri.query_values ||= {}
      uri.query_values = uri.query_values.merge({:source => @provider, :context => context})
      session[:return_to] = uri.to_s 
      render(:partial => "photos/auth") and return
    end

    # Try to look up a photo id
    if params[:q].to_i != 0 && params[:q].to_i > 10000
      if fp = @flickr.photos.getInfo(:photo_id => params[:q])
        @photos = [FlickrPhoto.new_from_api_response(fp)]
      end
    else
      @friend_id = params[:object_id]
      @friend_id = nil if @friend_id == 'null' || @friend_id.blank?
      search_params = {}
      if context == 'user'
        search_params['user_id'] = current_user.flickr_identity.flickr_user_id
        @friend_id = nil
      elsif context == 'friends'
        if @friend_id.blank? # if context is friends, but no friend id specified, we want to show the friend selector
          @friends = flickr_friends
          render :partial => 'flickr/friends' and return
        end
        search_params['user_id'] = @friend_id
      elsif context == 'public'
        search_params['license'] = @license_numbers
        if params[:q].blank?
          search_params['safe_search'] = 1
          params[:q] = "nature"
        end
      end
      search_params['auth_token'] = current_user.flickr_identity.token if current_user.flickr_identity
      search_params['per_page'] = params[:limit] ||= 10
      search_params['text'] = params[:q]
      search_params['page'] = params[:page] ||= 1
      search_params['extras'] = 'date_upload,owner_name,url_sq,url_t,url_s,license'
      search_params['sort'] = 'relevance'
      begin
        @photos = @flickr.photos.search(search_params).map{|fp| FlickrPhoto.new_from_api_response(fp) }
      rescue FlickRaw::FailedResponse => e
        raise e unless e.message =~ /Invalid auth token/
        @reauthorization_needed = true
        Rails.logger.error "[ERROR #{Time.now}] #{e}"
      rescue Net::HTTPFatalError, JSON::ParserError => e
        Rails.logger.error "[ERROR #{Time.now}] #{e}"
        @photos = []
      end
    end

    # Determine whether we should include synclinks
    @synclink_base = params[:synclink_base] unless params[:synclink_base].blank?
    
    # TODO: Lookup matching flickr_photo objects
    # @matching_flickr_photos = case params[:context]
    #   when 'user'
    #     FlickrPhoto.joins(:observations).
    #       where(["observations.user_id = ?", current_user.id])
    #   else
    #     FlickrPhoto.where(native_photo_id: @photos.map(&:id))
    #   end
    partial = params[:partial].to_s
    partial = 'photo_list_form' unless %w(photo_list_form bootstrap_photo_list_form).include?(partial)
    respond_to do |format|
      format.html do
        render :partial => "photos/#{partial}", 
               :locals => {
                 :photos => @photos, 
                 :index => params[:index],
                 :synclink_base => @synclink_base,
                 :local_photos => false
               }
      end
    end
  end

  # This is the endpoint which allows a user to manager their flickr account
  # settings.  They use this endpoint after they have already gone through the
  # signup process.
  def options
    begin
      flickr = get_flickraw
      if current_user.flickr_identity
        @photos = flickr.photos.search(
          :user_id => current_user.flickr_identity.flickr_user_id, 
          :per_page => 6, 
          :extras => "url_sq")
      else
        @flickr_url = auth_url_for('flickr')
      end
    rescue FlickRaw::FailedResponse => e
      Rails.logger.error "[Error #{Time.now}] Flickr connection failed (#{e}): #{e.message}"
      Airbrake.notify(e, :request => request, :session => session)
      Logstasher.write_exception(e, request: request, session: session)
      flash[:notice] = <<-EOT
        Ack! Something went wrong connecting to Flickr. You might try unlinking 
        and re-linking your account. You can contact us at 
        #{CONFIG.help_email} if that doesn't work.  Error: #{e.message}
      EOT
    end
  end
  
  # Used by the options interface, this just removes the user's associated
  # flickr_identity
  def unlink_flickr_account
    if current_user.flickr_identity
      current_user.flickr_identity.destroy
      flash[:notice] = "We've dissassociated your Flickr account from your #{CONFIG.site_name} account."
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
    flickr = get_flickraw
    begin
      flickr.photos.removeTag(:tag_id => params[:tag_id] || params[:id])
    rescue Exception => e
      @error = e
    end
    
    respond_to do |format|
      format.json do
        unless @error
          render :json => nil
        else
          render :status => :unprocessable_entity, :json => @error
        end
      end
    end
  end

  def invite
    # params should include 'flickr_photo_id' and whatever else you want to add
    # to the observation, e.g. taxon_id, project_id, etc
    invite_params = params
    invite_params[:flickr_photo_id] ||= request.env['HTTP_REFERER'].to_s[/flickr.com\/photos\/[^\/]+\/(\d+)/,1]
    [:controller,:action].each{|k| invite_params.delete(k)}  # so, later on, new_observation_url(invite_params) doesn't barf
    session[:invite_params] = invite_params
    pa = if logged_in?
      current_user.provider_authorizations.where(:provider_name => :flickr)
    end
    redirect_to auth_url_for(:flickr, :scope => pa.try(:scope))
  end
  
  private
  def ensure_has_no_flickr_identity
    redirect_to(:action => 'options') and return if current_user.flickr_identity
  end

  def flickr_friends
    get_flickraw.contacts.getList
  end

end
