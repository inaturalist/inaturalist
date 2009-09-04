class FlickrPhotosController < ApplicationController
  def show
    @flickr_photo = FlickrPhoto.find_by_id(params[:id])
    respond_to do |format|
      format.js do
        partial = params[:partial] || 'photo'
        render :layout => false, :partial => partial
      end
    end
  end
end
