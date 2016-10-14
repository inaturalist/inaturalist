class ExplodedAtlasPlacesController < ApplicationController
  def create
    @exploded_atlas_place = ExplodedAtlasPlace.new(:place_id => params[:place_id].to_i, :atlas_id => params[:atlas_id].to_i)
    @exploded_atlas_place.save
    respond_to do |format|
      format.js
    end
  end
    
  def destroy
    @exploded_atlas_place = ExplodedAtlasPlace.find(params[:id])
    @exploded_atlas_place.destroy
    respond_to do |format|
      format.js
    end
  end
  
end
