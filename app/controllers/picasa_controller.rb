class PicasaController < ApplicationController
  before_filter :login_required
  verify :method => :delete, :only => "unlink"
  
  # Configure Picasa linkage
  def options
    if @picasa_identity = current_user.picasa_identity
      @picasa = Picasa.new(@picasa_identity.token)
      @picasa_photos = @picasa.recent_photos(@picasa_identity.picasa_user_id).entries
    else
      @auth_url = Picasa.authorization_url(url_for(:action => "authorize"))
    end
  end
  
  # Receives redirect from Google after initial auth
  def authorize
    begin
      @picasa = Picasa.authorize_request(self.request)
    rescue RubyPicasa::PicasaTokenError
      flash[:error] = "Picasa authorization failed!"
      return redirect_to :action => "link"
    end
    
    @picasa_identity = PicasaIdentity.find_or_create_by_user_id(current_user.id)
    @picasa_identity.token = @picasa.token
    @picasa_user = @picasa.user('default')
    @picasa_identity.picasa_user_id = @picasa_user.user
    @picasa_identity.save
    
    flash[:notice] = "Congrats, your iNaturalist and Picasa accunts have been linked!"
    redirect_to :action => "options"
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
    
    per_page = params[:limit].to_i || 10
    search_params[:max_results] = per_page
    search_params[:start_index] = (params[:page] || 1).to_i * per_page - per_page + 1
    search_params[:thumbsize] = RubyPicasa::Photo::VALID.join(',')
    
    results = picasa.search(params[:q], search_params)
    @photos = results.photos.map do |api_response|
      logger.debug "[DEBUG] api_response: #{api_response}"
      next unless api_response.is_a?(RubyPicasa::Photo)
      PicasaPhoto.new_from_api_response(api_response, :user => current_user)
    end.compact
    
    respond_to do |format|
      format.html do
        render :partial => 'flickr/photo_list_form', 
               :locals => {
                 :photos => @photos, 
                 :index => params[:index],
                 :synclink_base => @synclink_base
               }
      end
    end
  end
end