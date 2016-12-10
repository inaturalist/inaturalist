class AtlasesController < ApplicationController
  before_filter :authenticate_user!
  before_filter :admin_required
  layout "bootstrap"
  
  def new
    @atlas = Atlas.new(:taxon_id => params[:taxon_id].to_i)
  end
  
  def edit
    @atlas = Atlas.find(params[:id])
    @exploded_atlas_places = @atlas.exploded_atlas_places.includes(:place)
    @atlas_places = @atlas.places
  end
  
  def show
    @atlas = Atlas.find(params[:id])
    @atlas_places = @atlas.places
    @atlas_presence_places = @atlas.presence_places    
    respond_to do |format|
      format.html do
        @atlas_alterations = @atlas.atlas_alterations.includes(:place, :user).order("created_at DESC").limit(30).reverse
        @listed_taxon_alterations = @atlas.relevant_listed_taxon_alterations.includes(:place, :user).order("listed_taxon_alterations.created_at DESC").limit(30).reverse
        @atlas_place_json = {
          type: "FeatureCollection", 
          features: @atlas_places.select{|p| !(p.name == "Antarctica" && p.admin_level = 0) }.map{|p| 
            {presence: (@atlas_presence_places.map(&:id).include? p.id) ? true : false, name: p.name, id: p.id, type: "Feature", geometry: RGeo::GeoJSON.encode(p.place_geometry.geom)}
          }
        }
      end
      format.json { render :json => @atlas_presence_places.to_json }
    end
  end
  
  def create
    @atlas = Atlas.new(params[:atlas])
    respond_to do |format|
      if @atlas.save
        format.html { redirect_to(@atlas, :notice => 'Atlas was successfully created.') }
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
  
  ## Custom actions ############################################################
  
  def alter_atlas_presence
    taxon_id = params[:taxon_id]
    @place_id = params[:place_id]
    place = Place.find(@place_id)
    taxon = Taxon.find(taxon_id)
    lts = taxon.atlas.get_atlas_presence_place_listed_taxa(@place_id)
    if lts.count > 0
      lts.each do |lt|
        lt.updater = current_user
        lt.destroy
      end
      @presence = false
    else
      list_id = place.check_list_id
      ListedTaxon.create(taxon_id: taxon_id, place_id: @place_id, list_id: list_id, user_id: current_user.id)
      @presence = true
    end
    
    respond_to do |format|
      format.json { render json: {place_name: place.name, place_id: @place_id, presence: @presence}, status: :ok}
    end
  end
  
  def destroy_all_alterations
    atlas_id = params[:atlas_id]
    AtlasAlteration.where(atlas_id: atlas_id).destroy_all
    respond_to do |format| 
      format.json { render json: {}, status: :ok}
    end
  end
  
end
