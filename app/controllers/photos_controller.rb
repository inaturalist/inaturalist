class PhotosController < ApplicationController
  def show
    @photo = Photo.find_by_id(params[:id])
    respond_to do |format|
      format.js do
        partial = params[:partial] || 'photo'
        render :layout => false, :partial => partial
      end
    end
  end
end
