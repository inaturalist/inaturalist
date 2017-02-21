class ExplodedAtlasPlacesController < ApplicationController
  def create
    @exploded_atlas_place = ExplodedAtlasPlace.new(
      place_id: params[:place_id].to_i,
      atlas_id: params[:atlas_id].to_i
    )
    @exploded_atlas_place.save
    @atlas = Atlas.find( @exploded_atlas_place.atlas_id )
    if @atlas.is_active
      AtlasAlteration.create(
        atlas_id: @exploded_atlas_place.atlas_id,
        user_id: current_user.id,
        place_id: @exploded_atlas_place.place_id,
        action: "exploded"
      )
    end
    respond_to do |format|
      format.json do
        render json: {
          place_id: @exploded_atlas_place.place_id,
          place_name: @exploded_atlas_place.place.name
        }
      end
    end
  end
    
  def destroy
    @exploded_atlas_place = ExplodedAtlasPlace.find( params[:id] )
    place_id = @exploded_atlas_place.place_id
    place_name = @exploded_atlas_place.place.name
    @exploded_atlas_place.destroy
    @atlas = Atlas.find( @exploded_atlas_place.atlas_id )
    if @atlas.is_active
      AtlasAlteration.create(
        atlas_id: @exploded_atlas_place.atlas_id,
        user_id: current_user.id,
        place_id: @exploded_atlas_place.place_id,
        action: "collapsed"
      )
    end
    respond_to do |format|
      format.json { render json: { place_id: place_id, place_name: place_name } }
    end
  end
   
end
