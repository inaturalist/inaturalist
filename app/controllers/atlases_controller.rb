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
    @atlas_alterations = @atlas.atlas_alterations.includes(:place, :user).order("created_at DESC").limit(30).reverse_order
    @atlas_place_json = {
      type: "FeatureCollection", 
      features: @atlas_places.map{|p| 
        {presence: (@atlas_presence_places.map(&:id).include? p.id) ? true : false, name: p.name, id: p.id, type: "Feature", geometry: RGeo::GeoJSON.encode(p.place_geometry.geom)}
      }
    }
    
    respond_to do |format|
      format.html
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
    if listed_taxon = ListedTaxon.where(taxon_id: taxon_id, place_id: @place_id).first
      listed_taxon.updater = current_user
      listed_taxon.destroy
      @presence = false
    else
      list_id = Place.find(@place_id).check_list_id
      ListedTaxon.create(taxon_id: taxon_id, place_id: @place_id, list_id: list_id, user_id: current_user.id)
      @presence = true
    end
    
    respond_to do |format|
      atlas = Atlas.where(taxon_id: taxon_id).first
      atlas_alteration = AtlasAlteration.where(place_id: @place_id, atlas_id: atlas.id, action: @presence ? "created" : "destroyed").last
      user_string = atlas_alteration.user_id.nil? ? "" : "<a href='/user/#{atlas_alteration.user_id}'>#{atlas_alteration.user.login}</a>"
      @alteration_row = "<tr>
        <th scope='row'>#{atlas_alteration.id}</th>
        <td><a href='/places/#{atlas_alteration.place_id}'>#{atlas_alteration.place.name}</a></td>
        <td>#{atlas_alteration.action}</td>
        <td>#{user_string}</td>
        <td>#{atlas_alteration.created_at}</td>
      </tr>".gsub(/\s+/, ' ').strip
      puts @alteration_row
      format.js
    end
  end
end
