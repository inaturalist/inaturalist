class PhotosController < ApplicationController
  def show
    return render_404 unless @photo = Photo.find_by_id(params[:id])
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
end
