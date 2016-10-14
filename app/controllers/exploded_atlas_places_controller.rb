class ExplodedAtlasPlacesController < ApplicationController
  def create
    @exploded_atlas_place = ExplodedAtlasPlace.new(:place_id => params[:place_id].to_i, :atlas_id => params[:atlas_id].to_i)
    @exploded_atlas_place.save
    AtlasAlteration.create(
      atlas_id: @exploded_atlas_place.atlas_id,
      user_id: current_user,
      place_id: @exploded_atlas_place.place_id,
      action: "exploded"
    )
    respond_to do |format|
      format.js
    end
  end
    
  def destroy
    @exploded_atlas_place = ExplodedAtlasPlace.find(params[:id])
    @exploded_atlas_place.destroy
    AtlasAlteration.create(
      atlas_id: @exploded_atlas_place.atlas_id,
      user_id: current_user,
      place_id: @exploded_atlas_place.place_id,
      action: "collapsed"
    )
    respond_to do |format|
      format.js
    end
  end
   
end
