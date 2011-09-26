class PhotosController < ApplicationController
  def show
    return render_404 unless @photo = Photo.find_by_id(params[:id])
    respond_to do |format|
      format.js do
        partial = params[:partial] || 'photo'
        render :layout => false, :partial => partial, :object => @photo
      end
    end
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

  def invite
    # params should include '#{flickr || facebook}_photo_id' and whatever else you want to add
    # to the observation, e.g. taxon_id, project_id, etc
    invite_params = params
    [:controller,:action].each{|k| invite_params.delete(k)}  # so, later on, new_observation_url(invite_params) doesn't barf
    provider = invite_params.delete(:provider)
    session[:invite_params] = invite_params
    redirect_to "/auth/#{provider}"
  end

end
