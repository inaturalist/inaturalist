class PhotosController < ApplicationController
  def show
    @photo = Photo.find_by_id(params[:id])
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
end
