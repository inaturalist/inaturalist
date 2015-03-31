#encoding: utf-8
class PlacesController < ApplicationController
  include Shared::WikipediaModule
  include Shared::GuideModule
  
  before_filter :authenticate_user!, :except => [:index, :show, :search, 
    :wikipedia, :taxa, :children, :autocomplete, :geometry, :guide,
    :cached_guide, :guide_widget]
  before_filter :return_here, :only => [:show]
  before_filter :load_place, :only => [:show, :edit, :update, :destroy, 
    :children, :taxa, :geometry, :cached_guide, :guide_widget, :widget, :merge]
  before_filter :limit_page_param_for_search, :only => [:search]
  before_filter :editor_required, :only => [:edit, :update, :destroy]
  
  caches_page :geometry
  caches_page :cached_guide
  cache_sweeper :place_sweeper, :only => [:update, :destroy, :merge]
  
  ALLOWED_SHOW_PARTIALS = %w(autocomplete_item)
  
  def index
    respond_to do |format|
      format.html do
        place = (Place.find(CONFIG.place_id) rescue nil) unless CONFIG.place_id.blank?
        key = place ? "random_place_ids_#{place.id}" : 'random_place_ids'
        place_ids = Rails.cache.fetch(key, :expires_in => 15.minutes) do
          places = if place
            place.children.select('id').order("RANDOM()").limit(50)
          else
            Place.where("place_type = ?", Place::COUNTRY_LEVEL).select(:id).
              order("RANDOM()").limit(50)
          end
          places.map{|p| p.id}
        end
        place_ids = place_ids.sort_by{rand}[0..4]
        @places = Place.where("id in (?)", place_ids)
      end
      
      format.json do
        @ancestor = Place.find_by_id(params[:ancestor_id].to_i) unless params[:ancestor_id].blank?
        scope = if @ancestor
          @ancestor.descendants
        else
          Place.all
        end
        if params[:q] || params[:term]
          q = (params[:q] || params[:term]).to_s.sanitize_encoding
          scope = scope.dbsearch(q)
        end
        if !params[:place_type].blank?
          scope = scope.place_type(params[:place_type])
        elsif !params[:place_types].blank?
          scope = scope.place_types(params[:place_types])
        end
        unless params[:taxon].blank?
          if !params[:place_type].blank? && params[:place_type].downcase == 'continent'
            country_scope = Place.place_types(['country']).listing_taxon(params[:taxon])
            if ListedTaxon::ESTABLISHMENT_MEANS.include?(params[:establishment_means])
              country_scope = country_scope.with_establishment_means(params[:establishment_means])
            end
            continent_ids = country_scope.select("ancestry").map(&:parent_id)
            scope = scope.where("places.id IN (?)", continent_ids)
          else
            scope = scope.listing_taxon(params[:taxon])
            if ListedTaxon::ESTABLISHMENT_MEANS.include?(params[:establishment_means])
              scope = scope.with_establishment_means(params[:establishment_means])
            end
          end
        end
        if !params[:latitude].blank? && !params[:longitude].blank?
          lat = params[:latitude].to_f
          lon = params[:longitude].to_f
          scope = scope.containing_lat_lng(lat, lon)
        end
        per_page = params[:per_page].to_i
        per_page = 200 if per_page > 200
        per_page = 30 if per_page < 1
        render :json => scope.paginate(:page => params[:page], :per_page => per_page).to_a
      end
    end
  end
  
  def search
    search_for_places
    respond_to do |format|
      format.html do
        if @places.size == 1
          redirect_to @places.first
        end
      end
      format.json do
        render(:json => @places.to_json(:methods => [ :html, :kml_url ]))
      end
    end
  end
  
  def show
    @place_geometry = PlaceGeometry.without_geom.where(place_id: @place).first
    browsing_taxon_ids = Taxon::ICONIC_TAXA.map{|it| it.ancestor_ids + [it.id]}.flatten.uniq
    browsing_taxa = Taxon.joins(:taxon_names).where(id: browsing_taxon_ids).
      where("taxon_names.name != 'Life'").includes(taxon_names: :place_taxon_names).
      order(:ancestry, :name)
    @arranged_taxa = Taxon.arrange_nodes(browsing_taxa)
    respond_to do |format|
      format.html do
        @projects = Project.in_place(@place).page(1).order("projects.title").per_page(50)
        @wikipedia = WikipediaService.new
        if logged_in?
          @subscriptions = @place.update_subscriptions.where(:user_id => current_user)
        end
      end
      format.json do
        if (partial = params[:partial]) && ALLOWED_SHOW_PARTIALS.include?(partial)
          @place.html = render_to_string(:partial => "#{partial}.html.erb", :object => @place)
        end
        render(:json => @place.to_json(
          :methods => [:place_type_name, :html])
        )
      end
    end
  end
  
  def geometry
    respond_to do |format|
      format.kml do
        if @place.place_geometry_without_geom
          @kml = Place.connection.execute("SELECT ST_AsKML(ST_SetSRID(geom, 4326)) AS kml FROM place_geometries WHERE place_id = #{@place.id}")[0]['kml']
        end
      end
      format.geojson do
        @geojson = Place.connection.execute("SELECT ST_AsGeoJSON(ST_SetSRID(geom, 4326)) AS geojson FROM place_geometries WHERE place_id = #{@place.id}")[0]['geojson']
        render :json => @geojson
      end
    end
  end
  
  def new
    @place = Place.new
  end
  
  def create
    if params[:woeid]
      @place = Place.import_by_woeid(params[:woeid])
    else
      @place = Place.new(params[:place])
      @place.user = current_user
      @place.save
      if params[:file]
        assign_geometry_from_file
      elsif !params[:geojson].blank?
        @geometry = geometry_from_geojson(params[:geojson])
        @place.save_geom(@geometry) if @geometry
      end
      if @geometry && @place.valid?
        @place.save_geom(@geometry)
        if @place.too_big_for_check_list?
          notice = t(:place_too_big_for_check_list)
          @place.check_list.destroy if @place.check_list
          @place.update_attributes(:prefers_check_lists => false)
        end
      end
    end
    
    if @place.valid?
      notice ||= t(:place_imported)
      flash[:notice] = notice
      return redirect_to @place
    else
      flash[:error] = t(:there_were_problems_importing_that_place, :place_error => @place.errors.full_messages.join(', '))
      render :action => :new
    end
  end
  
  def edit
    r = Place.connection.execute("SELECT st_npoints(geom) from place_geometries where place_id = #{@place.id}")
    @npoints = r[0]['st_npoints'].to_i unless r.num_tuples == 0
  end
  
  def update
    if @place.update_attributes(params[:place])
      if params[:file]
        assign_geometry_from_file
      elsif !params[:geojson].blank?
        @geometry = geometry_from_geojson(params[:geojson])
        @place.save_geom(@geometry) if @geometry
      end

      if params[:remove_geom]
        @place.place_geometry_without_geom.delete
      end

      if !@place.valid?
        render :action => :edit
        return
      end
      
      if @place.place_geometry && !@place.place_geometry.valid?
        flash[:error] = "Place updated, but boundary shape was invalid: #{@place.place_geometry.errors.full_messages.to_sentence}"
        flash[:error] += " You may have to edit the KML directly to fix issues like slivers."
        render :action => :edit
        return
      end
      
      flash[:notice] = t(:place_updated)
      redirect_to @place
    else
      render :action => :edit
    end
  end
  
  def destroy
    errors = []
    errors << "there are people using this place in their projects" if @place.projects.exists?
    errors << "there are people using this place in their guides" if @place.guides.exists?
    if errors.blank?
      @place.destroy
      flash[:notice] = t(:place_deleted)
      redirect_to places_path
    else
      flash[:error] = "Couldn't delete place: #{errors.to_sentence}"
      redirect_back_or_default places_path
    end
  end
  
  def find_external
    @places = if @ydn_places = GeoPlanet::Place.search(params[:q], :count => 10)
      @ydn_places.map {|ydnp| Place.new_from_geo_planet(ydnp)}
    else
      []
    end
    
    respond_to do |format|
      format.json do
        @places.each_with_index do |place, i|
          @places[i].html = view_context.render_in_format(:html, :partial => "create_external_place_link", :object => place, :locals => {:i => i})
        end
        render :json => @places.to_json(:methods => [:html])
      end
    end
  end
  
  def autocomplete
    @q = params[:q] || params[:term] || params[:item]
    @q = sanitize_sphinx_query(@q.to_s.sanitize_encoding)
    site_place = @site.place if @site
    if @q.blank?
      scope = if site_place
        Place.where(site_place.child_conditions)
      else
        Place.where("place_type = ?", Place::CONTINENT).order("updated_at desc")
      end
      scope = scope.with_geom if params[:with_geom]
      @places = scope.includes(:place_geometry_without_geom).limit(30).
        sort_by{|p| p.bbox_area || 0}.reverse
    else
      search_wheres = { display_name_autocomplete: @q }
      if site_place
        search_wheres["ancestor_place_ids"] = site_place
      end
      @places = Place.elastic_paginate(
        where: search_wheres,
        fields: [ :id ],
        sort: { bbox_area: "desc" })
      Place.preload_associations(@places, :place_geometry_without_geom)
    end

    respond_to do |format|
      format.html do
        render :layout => false, :partial => 'autocomplete' 
      end
      format.json do
        @places.each_with_index do |place, i|
          @places[i].html = view_context.render_in_format(:html, :partial => 'places/autocomplete_item', :object => place)
        end
        render :json => @places.to_json(:methods => [:html, :kml_url])
      end
    end
  end
  
  def merge
    @merge_target = Place.find(params[:with]) rescue nil
    
    if request.post?
      keepers = params.map do |k,v|
        k.gsub('keep_', '') if k =~ /^keep_/ && v == 'left'
      end.compact
      keepers = nil if keepers.blank?
      unless @merge_target
        flash[:error] = t(:you_must_select_a_place_to_merge_with)
        return
      end
      
      @merged = @merge_target.merge(@place, :keep => keepers)
      if @merged.valid?
        flash[:notice] = t(:places_merged_successfully)
        redirect_to @merged
      else
        flash[:error] = t(:there_merge_problems_with_the_merge, :merged_errors => @merged.errors.full_messages.join(', '))
      end
    end
  end
  
  def children
    per_page = params[:per_page]
    per_page = 100 if per_page && per_page > 100
    @children = @place.children.order(:name).
      paginate(page: params[:page], per_page: per_page)

    respond_to do |format|
      format.html { render :partial => "place_li", :collection => @children }
      format.json { render :json => @children.to_json }
    end
  end
  
  def taxa
    per_page = params[:per_page]
    per_page = 100 if per_page && per_page.to_i > 100
    conditions = params[:photos_only] ? "photos.id IS NOT NULL" : nil
    listed_taxa = @place.listed_taxa.paginate(
      :page => params[:page],
      :per_page => per_page,
      :select => "MAX(listed_taxa.id) AS id, listed_taxa.taxon_id",
      :joins => 
        "LEFT OUTER JOIN taxon_photos ON taxon_photos.taxon_id = listed_taxa.taxon_id " +
        "LEFT OUTER JOIN photos ON photos.id = taxon_photos.photo_id",
      :group => "listed_taxa.taxon_id",
      :order => "id DESC",
      :conditions => conditions
    )
    @taxa = Taxon.where(id: listed_taxa.map(&:taxon_id)).
      includes(:iconic_taxon, :photos, :taxon_names)
    
    respond_to do |format|
      format.html { redirect_to @place }
      format.json do
        @taxa.map! do |taxon|
          taxon.html = render_to_string(:partial => 'taxa/taxon.html.erb', 
            :object => taxon, :locals => {
              :image_options => {:size => 'small'},
              :link_image => true,
              :link_name => true,
              :include_image_attribution => true
          })
          taxon
        end
        render :json => @taxa.to_json(
          :include => :photos, 
          :methods => [:image_url, :default_name, :common_name, 
            :scientific_name, :html])
      end
    end
  end
  
  # page cached version of guide
  def cached_guide
    params.delete_if{|k,v| !%w(controller action id).include?(k.to_s)}
    guide
  end
  
  def guide
    place_id = params[:id] || params[:place_id] || params[:place]
    @place ||= if place_id.to_i == 0
      begin
        Place.find(place_id)
      rescue ActiveRecord::RecordNotFound
        Place.elastic_paginate(where: { display_name: place_id }, per_page: 1).first
      end
    else
      Place.find_by_id(place_id.to_i)
    end
    return render_404 unless @place
    @place_geometry = PlaceGeometry.without_geom.where(place_id: @place).first
    
    show_guide do |scope|
      scope = scope.from_place(@place)
      scope = scope.where("listed_taxa.primary_listing = true")
      scope = scope.where([
        "listed_taxa.occurrence_status_level IS NULL OR listed_taxa.occurrence_status_level IN (?)",
        ListedTaxon::PRESENT_EQUIVALENTS])
      if @introduced = @filter_params[:introduced]
        scope = scope.where(["listed_taxa.establishment_means IN (?)", ListedTaxon::INTRODUCED_EQUIVALENTS])
      elsif @native = @filter_params[:native]
        scope = scope.where(["listed_taxa.establishment_means IN (?)", ListedTaxon::NATIVE_EQUIVALENTS])
      elsif @establishment_means = @filter_params[:establishment_means]
        if @establishment_means == "native"
          scope = scope.where(["listed_taxa.establishment_means IN (?)", ListedTaxon::NATIVE_EQUIVALENTS])
        elsif @establishment_means == "introduced"
          scope = scope.where(["listed_taxa.establishment_means IN (?)", ListedTaxon::INTRODUCED_EQUIVALENTS])
        else
          scope = scope.where(["listed_taxa.establishment_means = ?", @establishment_means])
        end
      end
      
      if @filter_params.blank?
        # scope = scope.has_photos
        @order = "listed_taxa.observations_count DESC, listed_taxa.id ASC"
      end
      scope
    end
    
    if @taxon
      ancestor_ids = @taxon.ancestor_ids + [@taxon.id]
      @comprehensive = @place.check_lists.exists?(["taxon_id IN (?) AND comprehensive = 't'", ancestor_ids])
      @comprehensive_list = @place.check_lists.where(taxon_id: ancestor_ids, comprehensive: "t").first
    end
    @listed_taxa_count = @scope.count("taxa.id", distinct: true)
    @confirmed_listed_taxa_count = @scope.where("listed_taxa.first_observation_id IS NOT NULL").
      count("taxa.id", distinct: true)
    @listed_taxa = @place.listed_taxa
                         .where(taxon_id: @taxa, primary_listing: true)
                         .includes([ :place, { :first_observation => :user } ])
    @listed_taxa_by_taxon_id = @listed_taxa.index_by{|lt| lt.taxon_id}
    
    render :layout => false, :partial => @partial
  end
  
  def widget
    
  end
  
  def guide_widget
    @guide_url = place_guide_url(@place)
    show_guide_widget
    render :template => "guides/guide_widget"
  end
  
  private
  
  def load_place
    @place = Place.find(params[:id]) rescue nil
    if @place.blank?
      if params[:id].to_i > 0 || params[:id] == "0"
        return render_404
      else
        return redirect_to place_search_path(:q => params[:id])
      end
    end
  end
  
  def filter_wikipedia_content
    hhtml = Nokogiri::HTML(@decoded)
    hhtml.search('table[id=toc], table.metadata').remove
    @decoded = hhtml.to_s
    @decoded.gsub!(/\[\d+\]/, '')
    @decoded.gsub!(/width:\d+/, '')
    @decoded.gsub!(/white-space:\s?nowrap/, '')
  end
  
  def geometry_from_messy_kml(kml)
    geometry = GeoRuby::SimpleFeatures::MultiPolygon.new
    doc = kml =~ /\<kml / ? Nokogiri::XML(kml) : Nokogiri::XML.fragment(kml)
    doc.search('Polygon').each_with_index do |hpoly,i|
      poly = GeoRuby::SimpleFeatures::Geometry.from_kml(hpoly.to_s)

      # make absolutely sure there are no z coordinates. iNat is strictly 2D, 
      # so PostGIS will raise db exception if you try to save z
      poly.rings.each_with_index do |r,i|
        poly.rings[i].points.each_with_index do |p,j|
          poly.rings[i].points[j].z = nil
          poly.rings[i].points[j].with_z = false
        end
        poly.rings[i].with_z = false
      end
      poly.with_z = false

      geometry << poly
    end
    geometry.empty? ? nil : geometry
  end

  def geometry_from_geojson(geojson)
    geometry = GeoRuby::SimpleFeatures::MultiPolygon.new
    collection = GeoRuby::SimpleFeatures::Geometry.from_geojson(geojson)
    collection.features.each do |feature|
      geometry << feature.geometry
    end
    geometry
  end

  def geometry_from_file(file)
    kml = file.read
    geometry_from_messy_kml(kml)
  end

  def editor_required
    unless @place.editable_by?(current_user)
      flash[:error] = t(:you_dont_have_permission_to_do_that)
      redirect_back_or_default(@place)
      return false
    end
    true
  end

  def assign_geometry_from_file
    limit = current_user && current_user.is_curator? ? 5.megabytes : 1.megabyte
    if params[:file].size > limit
      # can't really add errors to model from here, unfortunately
    else
      @geometry = geometry_from_file(params[:file])
      @place.save_geom(@geometry) if @geometry
    end
  end
end
