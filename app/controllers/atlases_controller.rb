class AtlasesController < ApplicationController
  before_filter :curator_required
  
  def new
    @atlas = Atlas.new(:taxon_id => params[:taxon_id].to_i)
  end
  
  def edit
    @atlas = Atlas.find(params[:id])
  end
  
  def show
    @atlas = Atlas.find(params[:id])
    @atlas_places = @atlas.places[0..10]
    @atlas_presence_places = @atlas.presence_places
    @atlas_alterations = @atlas.atlas_alterations
    @atlas_place_json = {
      type: "FeatureCollection", 
      features: @atlas_places.map{|p| 
        {presence: (@atlas_presence_places.map(&:id).include? p.id) ? true : false, id: p.id, type: "Feature", geometry: RGeo::GeoJSON.encode(p.place_geometry.geom)}
      }
    }
    @listed_taxon = ListedTaxon.where(place_id: @atlas_presence_places.first.id).first
  end
  
  def create
    @atlas = Atlas.new(params[:atlas])

    respond_to do |format|
      if @atlas.save
        format.html { redirect_to(@atlas.taxon || taxa_path, :notice => 'Atlas was successfully created.') }
      else
        format.html { render :action => "new" }
      end
    end
  end
  
  def update
    @atlas = Atlas.find(params[:id])
    respond_to do |format|
      if @atlas.update_attributes(params[:atlas])
        @atlas.taxon
        format.html { redirect_to(@atlas.taxon || taxa_path, :notice => 'Atlas was successfully updated.') }
      else
        format.html { render :action => "edit" }
      end
    end
  end
  
  def destroy
    @atlas = Atlas.find(params[:id])
    @atlas.destroy
    
    respond_to do |format|
      format.html { redirect_to(@atlas.taxon) }
    end
  end
  
  def alter_atlas_presence
    taxon_id = params[:taxon_id]
    @place_id = params[:place_id]
    if listed_taxon = ListedTaxon.where(taxon_id: taxon_id, place_id: @place_id).first
      listed_taxon.destroy
      @presence = false
    else
      list_id = Place.find(@place_id).check_list_id
      ListedTaxon.create(taxon_id: taxon_id, place_id: @place_id, list_id: list_id)
      @presence = true
    end
    
    respond_to do |format|
      format.js
    end
  end
end
