class PlacesController < ApplicationController
  include Shared::WikipediaModule
  
  before_filter :login_required, :except => [:index, :show, :search, 
    :wikipedia, :taxa, :children, :autocomplete, :geometry, :guide, :cached_guide]
  before_filter :return_here, :only => [:show]
  before_filter :load_place, :only => [:show, :edit, :update, :destroy, 
    :children, :taxa, :geometry, :guide, :cached_guide]
  before_filter :limit_page_param_for_thinking_sphinx, :only => [:search]
  before_filter :editor_required, :only => [:edit, :update, :destroy]
  
  caches_page :geometry
  caches_page :cached_guide
  
  def index
    place_ids = Rails.cache.fetch('random_place_ids', :expires_in => 15.minutes) do
      place_types = [Place::PLACE_TYPE_CODES['Country']]
      places = Place.all(:select => "id", :order => "RANDOM()", :limit => 50, 
        :conditions => ["place_type IN (?)", place_types])
      places.map{|p| p.id}
    end
    place_ids = place_ids.sort_by{rand}[0..4]
    @places = Place.all(:conditions => ["id in (?)", place_ids])
    
    respond_to do |format|
      format.html
    end
  end
  
  def search
    search_for_places
    if @places.size == 1
      redirect_to @places.first
    end
  end
  
  def show
    @place_geometry = PlaceGeometry.without_geom.first(:conditions => {:place_id => @place})
    if logged_in?
      scope = @place.taxa.of_rank(Taxon::SPECIES).scoped({:select => "DISTINCT ON (ancestry, taxa.id) taxa.*"})
      @listed_taxa_count = scope.count
      @current_user_observed_count = scope.count(
        :joins => "JOIN listed_taxa ult ON ult.taxon_id = listed_taxa.taxon_id", 
        :conditions => ["ult.list_id = ?", current_user.life_list_id])
    end
    browsing_taxon_ids = Taxon::ICONIC_TAXA.map{|it| it.ancestor_ids + [it.id]}.flatten.uniq
    browsing_taxa = Taxon.all(:conditions => ["id in (?)", browsing_taxon_ids], :order => "ancestry", :include => [:taxon_names])
    browsing_taxa.delete_if{|t| t.name == "Life"}
    @arranged_taxa = Taxon.arrange_nodes(browsing_taxa)
  end
  
  def geometry
    @place_geometry = @place.place_geometry
    respond_to do |format|
      format.kml
      format.geojson do
        render :json => [@place_geometry].to_geojson
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
      unless params[:kml].blank?
        @geometry = geometry_from_messy_kml(params[:kml])
        @place.save_geom(@geometry) if @geometry && @place.valid?
      end
    end
    
    if @place.valid?
      flash[:notice] = "Place imported!"
      return redirect_to @place
    else
      flash[:error] = "There were problems importing that place: " + 
        @place.errors.full_messages.join(', ')
      render :action => :new
    end
  end
  
  def edit
    @geometry = @place.place_geometry.geom if @place.place_geometry
  end
  
  def update
    if @place.update_attributes(params[:place])
      unless params[:kml].blank?
        @geometry = geometry_from_messy_kml(params[:kml])
        @place.save_geom(@geometry) if @geometry
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
      
      expire_page :action => "geometry", :id => @place.id
      flash[:notice] = "Place updated!"
      redirect_to @place
    else
      render :action => :edit
    end
  end
  
  def destroy
    @place.destroy
    flash[:notice] = "Place deleted."
    redirect_to places_path
  end
  
  def find_external
    @places = if @ydn_places = GeoPlanet::Place.search(params[:q], :count => 10)
      @ydn_places.map {|ydnp| Place.new_from_geo_planet(ydnp)}
    else
      []
    end
    
    respond_to do |format|
      format.json { render :json => @ydn_places }
      format.js do
        render :update do |page|
          if @places.blank?
            page.alert "No matching places found."
          else
            page << "addPlaces(#{@places.to_json})"
            page['places'].replace_html :partial => 'create_external_place_links'
          end
        end
      end
    end
  end
  
  def autocomplete
    @places = Place.paginate(:page => params[:page], 
      :conditions => ["lower(display_name) LIKE ?", "#{params[:q].to_s.downcase}%"])
    render :layout => false, :partial => 'autocomplete'
  end
  
  def merge
    @place = Place.find_by_id(params[:id].to_i)
    @merge_target = Place.find_by_id(params[:with].to_i)
    
    if request.post?
      keepers = params.map do |k,v|
        k.gsub('keep_', '') if k =~ /^keep_/ && v == 'left'
      end.compact
      keepers = nil if keepers.blank?
      
      unless @merge_target
        flash[:error] = "You must select a place to merge with."
        return
      end
      
      @merged = @merge_target.merge(@place, :keep => keepers)
      if @merged.valid?
        flash[:notice] = "Places merged successfully!"
        redirect_to @merged
      else
        flash[:error] = "There merge problems with the merge: " +
          @merged.errors.full_messages.join(', ')
      end
    end
  end
  
  def children
    per_page = params[:per_page]
    per_page = 100 if per_page && per_page > 100
    @children = @place.children.paginate(:page => params[:page], 
      :per_page => per_page, :order => 'name')
    
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
    @taxa = Taxon.all(
      :conditions => ["id IN (?)", listed_taxa.map(&:taxon_id)],
      :include => [:iconic_taxon, :photos, :taxon_names]
    )
    
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
    @place_geometry = PlaceGeometry.without_geom.first(:conditions => {:place_id => @place})
    filter_param_keys = [:colors, :taxon, :q]
    @filter_params = Hash[params.select{|k,v| 
      is_filter_param = filter_param_keys.include?(k.to_sym)
      is_blank = if v.is_a?(Array) && v.size == 1
        v[0].blank?
      else
        v.blank?
      end
      is_filter_param && !is_blank
    }].symbolize_keys
    scope = @place.taxa.of_rank(Taxon::SPECIES).scoped({})
    order = nil
    if @q = @filter_params[:q]
      @q = @q.to_s
      @search_taxon_ids = Taxon.search_for_ids(@q, :per_page => 1000, :with => {:places => [@place.id]})
      @search_taxon_ids = Taxon.search_for_ids(@q) if @search_taxon_ids.blank?
      if @search_taxon_ids.size == 1
        @taxon = Taxon.find_by_id(@search_taxon_ids.first)
      elsif Taxon.count(:conditions => ["id IN (?) AND name LIKE ?", @search_taxon_ids, "#{@q.capitalize}%"]) == 1
        @taxon = Taxon.first(:conditions => ["name = ?", @q.capitalize])
      else
        scope = scope.among(@search_taxon_ids)
      end
    end
    
    if @filter_params[:taxon]
      @taxon = Taxon.find_by_id(@filter_params[:taxon].to_i) if @filter_params[:taxon].to_i > 0
      @taxon ||= TaxonName.first(:conditions => [
        "lower(name) = ?", @filter_params[:taxon].to_s.strip.gsub(/[\s_]+/, ' ').downcase]
      ).try(:taxon)
    end
    if @taxon
      scope = if @taxon.species_or_lower? 
        scope.self_and_descendants_of(@taxon)
      else
        scope.descendants_of(@taxon)
      end
      order = "ancestry, taxa.id"
    end
    
    if @colors = @filter_params[:colors]
      scope = scope.colored(@colors)
    end
    
    @listed_taxa_count = scope.count(:select => "DISTINCT taxa.id")
    @confirmed_listed_taxa_count = scope.count(:select => "DISTINCT taxa.id",
      :conditions => "listed_taxa.first_observation_id IS NOT NULL")
    if logged_in?
      @current_user_observed_count = scope.count(
        :select => "DISTINCT taxa.id",
        :joins => "JOIN listed_taxa ult ON ult.taxon_id = taxa.id", 
        :conditions => ["ult.list_id = ?", current_user.life_list_id])
    end
    
    if @filter_params.blank?
      scope = scope.has_photos
      order = "listed_taxa.observations_count DESC, listed_taxa.id DESC"
    end
    
    @taxa = scope.paginate( 
      :select => "DISTINCT ON (ancestry, taxa.id) taxa.*",
      :include => [:taxon_names, :photos],
      :order => order,
      :page => params[:page], :per_page => 50)
    @taxa_by_taxon_id = @taxa.index_by{|t| t.id}
    @listed_taxa = @place.listed_taxa.all(
      :select => "DISTINCT ON (taxon_id) listed_taxa.*", 
      :conditions => ["taxon_id IN (?)", @taxa])
    @listed_taxa_by_taxon_id = @listed_taxa.index_by{|lt| lt.taxon_id}
    
    render :layout => false, :partial => "guide_taxa"
  end
  
  private
  
  def load_place
    render_404 unless @place = Place.find_by_id(params[:id], 
      :include => [:check_list])
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
    Hpricot.XML(kml).search('Polygon').each do |hpoly|
      geometry << GeoRuby::SimpleFeatures::Geometry.from_kml(hpoly.to_s)
    end
    geometry.empty? ? nil : geometry
  end
  
  def search_places_for_index(options)
    session[:places_index_q] = @q
    
    conditions = if options[:conditions] && options[:conditions][:place_type]
      conditions = update_conditions(
        ["place_type = ?", options[:conditions][:place_type]], 
        ["AND display_name LIKE ?", "#{@q}%"])
    else
      ["display_name LIKE ?", "#{@q}%"]
    end
    @place = Place.first(:conditions => conditions)
    if logged_in? && @place.blank?
      @ydn_places = GeoPlanet::Place.search(@q, :count => 2)
      if @ydn_places && @ydn_places.size == 1
        @place = Place.import_by_woeid(@ydn_places.first.woeid)
      end
    end
    
    begin
      if @place
        latrads = @place.latitude.to_f * (Math::PI / 180)
        lonrads = @place.longitude.to_f * (Math::PI / 180)
        nearby_options = options.merge(
          :geo => [latrads,lonrads], 
          :order => "@geodist asc")
        nearby_options[:with] = nearby_options.delete(:conditions)
        @places = Place.search(nearby_options)
        @places.delete_if {|p| p.id == @place.id}
      else
        @places = Place.search(@q, options.clone)
      end
    rescue ThinkingSphinx::ConnectionError
      @places = []
    end
  end
  
  def editor_required
    unless @place.editable_by?(current_user)
      flash[:error] = "You don't have permission to do that."
      redirect_back_or_default(@place)
      return false
    end
    true
  end
end
