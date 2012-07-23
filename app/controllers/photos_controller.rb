class PhotosController < ApplicationController
  MOBILIZED = [:show]
  before_filter :unmobilized, :except => MOBILIZED
  before_filter :mobilized, :only => MOBILIZED
  before_filter :load_photo, :only => [:show, :update]
  before_filter :require_owner, :only => [:update]
  before_filter :login_required, :only => [:inviter]
  
  def show
    @size = params[:size]
    @size = "medium" if !%w(small medium large original).include?(@size)
    respond_to do |format|
      format.html do
        if params[:partial]
          partial = params[:partial] || 'photo'
          render :layout => false, :partial => partial, :object => @photo
          return
        end
        @taxa = @photo.taxa.all(:limit => 100)
        @observations = @photo.observations.all(:limit => 100)
      end
      format.mobile
      format.js do
        partial = params[:partial] || 'photo'
        render :layout => false, :partial => partial, :object => @photo
      end
    end
  end
  
  def update
    if @photo.update_attributes(params[:photo])
      flash[:notice] = "Updated photo"
    else
      flash[:error] = "Error updating photo: #{@photo.errors.full_messages.to_sentence}"
    end
    redirect_to @photo.becomes(Photo)
  end
  
  def local_photo_fields
    # Determine whether we should include synclinks
    @synclink_base = params[:synclink_base] unless params[:synclink_base].blank?
    
    respond_to do |format|
      format.html do
        render :partial => 'photos/photo_list_form', 
               :locals => {
                 :photos => [], 
                 :index => params[:index],
                 :synclink_base => @synclink_base,
                 :local_photos => true
               }
      end
    end
  end

  # this is the action for *accepting* an invite (e.g. coming from a url posted as a flickr/fb/picasa photo comment)
  # params should include '#{flickr || facebook || picasa}_photo_id' and whatever else you want to add
  # to the observation, e.g. taxon_id, project_id, etc
  def invite
    invite_params = params
    [:controller,:action].each{|k| invite_params.delete(k)}  # so, later on, new_observation_url(invite_params) doesn't barf
    provider = invite_params.delete(:provider)
    session[:invite_params] = invite_params
    if request.user_agent =~ /facebookexternalhit/ || params[:test]
      @project = Project.find_by_id(params[:project_id].to_i)
      @taxon = Taxon.find_by_id(params[:taxon_id].to_i)
    else
      # we're not using omniauth for picasa, so it needs a special auth url.  
      if provider=='picasa'
        session[:return_to] = Picasa.authorization_url(url_for(:controller => "picasa", :action => "authorize")) 
        redirect_to signup_url and return
      else
        redirect_to "/auth/#{provider}"
      end
    end
  end

  def inviter
    @default_source = params[:source]
    @default_context = params[:context]
    @taxon = Taxon.find_by_id(params[:taxon_id].to_i) if params[:taxon_id]
    if params[:project_id]
      @project = Project.find(params[:project_id]) rescue Project.find_by_id(params[:project_id].to_i)
    end
    @projects = current_user.projects.all(:limit => 100, :order => :title)
    if request.post? # submitting the inviter form
      if !params[:comment].include?("{{INVITE_LINK}}")
        flash[:notice] = "You need to include the {{INVITE_LINK}} placeholder in your comment!"
        return
      end

      # params[:facebook_photos] looks like {"0" => ['fb_photo_id_1','fb_photo_id_2'],...} to accomodate multiple photo-selectors on the same page
      fb_photos = (params[:facebook_photos] || [])
      fb_photo_ids = (fb_photos.is_a?(Hash) && fb_photos.has_key?('0') ? fb_photos['0'] : [])
      
      flickr_photos = (params[:flickr_photos] || [])
      flickr_photo_ids = (flickr_photos.is_a?(Hash) && flickr_photos.has_key?('0') ? flickr_photos['0'] : [])

      picasa_photos = (params[:picasa_photos] || [])
      picasa_photo_urls = (picasa_photos.is_a?(Hash) && picasa_photos.has_key?('0') ? picasa_photos['0'] : [])

      if (fb_photo_ids.empty? && flickr_photo_ids.empty? && picasa_photo_urls.empty?)
        flash[:notice] = "You need to select at least one photo!"
        return
      end
      
      invite_params = {:taxon_id => params[:taxon_id], :project_id=>params[:project_id]}
      invite_params.delete_if { |k, v| v.nil? || v.empty? }

      fb_photo_ids.each{|fb_photo_id|
        invite_params[:facebook_photo_id] = fb_photo_id
        # invite_params should include '#{flickr || facebook}_photo_id' and whatever else you want to add
        # to the observation, e.g. taxon_id, project_id, etc
        current_user.facebook_api.put_comment(fb_photo_id, params[:comment].gsub("{{INVITE_LINK}}", fb_accept_invite_url(invite_params)))
      }

      get_flickraw unless flickr_photo_ids.empty?
      flickr_photo_ids.each{|flickr_photo_id|
        invite_params[:flickr_photo_id] = flickr_photo_id
        flickr.photos.comments.addComment(
          :user_id => current_user.flickr_identity.flickr_user_id, 
          :auth_token => current_user.flickr_identity.token,
          :photo_id => flickr_photo_id, 
          :comment_text => params[:comment].gsub("{{INVITE_LINK}}", flickr_accept_invite_url(invite_params))
        )
      }

      picasa_photo_urls.each{|picasa_photo_url|
        invite_params[:picasa_photo_id] = picasa_photo_url
        PicasaPhoto.add_comment(
          current_user, 
          picasa_photo_url, 
          params[:comment].gsub("{{INVITE_LINK}}", picasa_accept_invite_url(invite_params))
        )
      }

      flash[:notice] = "Your invites have been sent!"
      #render :text => 'ok' and return
    end
  end
  
  private
  
  def load_photo
    unless @photo = Photo.find_by_id(params[:id].to_i)
      render_404
    end
  end
  
  def require_owner
    unless logged_in? && @photo.editable_by?(current_user)
      flash[:error] = "You don't have permission to do that"
      return redirect_to @photo
    end
  end

end
