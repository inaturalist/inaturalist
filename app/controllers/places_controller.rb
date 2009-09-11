class PlacesController < ApplicationController
  include Shared::WikipediaModule
  
  before_filter :login_required, :except => [:index, :show, :search, 
    :wikipedia, :taxa, :children]
  before_filter :return_here, :only => [:show]
  before_filter :load_place, :only => [:show, :edit, :update, :destroy, 
    :children, :taxa]
  before_filter :limit_page_param_for_thinking_sphinx, :only => [:index, 
    :search]
  
  def index
    ip = request.remote_ip
    # ip = '66.117.138.26' # Emeryville IP, for testing
    limit = 9
    options = {
      :include => [:parent, :check_list],
      :limit => limit
    }
    unless params[:place_type].blank?
      options.merge!(:conditions => {:place_type => params[:place_type]})
    end
    @places = []
    @q = params[:q] || session[:places_index_q]
    if @q
      search_places_for_index(options)
    elsif GEOIP && (@geoip_result = GeoipTools.city(ip)) && 
        !@geoip_result[:latitude].blank? && @geoip_result[:latitude] <= 180
      lat = @geoip_result[:latitude]
      lon = @geoip_result[:longitude]
      @q = "#{@geoip_result[:city]}, #{@geoip_result[:state_code]}"
      @place = Place.first(:conditions => ["display_name LIKE ?", "#{@q}%"])
      latrads = lat.to_f * (Math::PI / 180)
      lonrads = lon.to_f * (Math::PI / 180)
      @places = Place.search(options.merge(:geo => [latrads,lonrads], 
        :order => "@geodist asc", :limit => limit)) rescue []
    end
    
    @places = if @place && @places.size > 2
      @places.insert(2, @place)
    else
      @places.insert(0, @place)
    end.compact
    
    # If the IP geocoding failed for some reason...
    logger.debug "[DEBUG] @places.size: #{@places.size}"
    if @places.size < limit && @places.size > 0
      if @place
        # Backfill with child places
        @places += Place.all(:limit => (limit - @places.size), 
          :conditions => ["parent_id = ?", @place.parent_id])
        @places.delete_if{|p| p.id == @place.id}
        @places = @places[0..limit]
      else
        # Grab random places
        places_count = Place.count
        # test_place = Place.find_by_name_and_place_type('Oakland', Place::PLACE_TYPE_CODES['Town'])
        limit.times do |i|
          place = Place.first(options.merge(:offset => rand(places_count)))
          # place = test_place.children.first(:offset => i)
          @places << place
        end
      end
    end
    
    @places.compact!
    
    @taxa_by_place_id = {}
    @places.each do |place|
      @taxa_by_place_id[place.id] = place.taxa.paginate(
        :page => 1, 
        :per_page => 6, 
        :include => [:flickr_photos, :taxon_names, :iconic_taxon], 
        :order => "flickr_photos.id DESC")
    end
    
    respond_to do |format|
      format.html
      format.js do
        render :update do |page|
          if @places.empty?
            page << "showNoPlaces()"
          else
            @place ||= @places.first
            page << "hideNoPlaces()"
            page << "map.removePlaces()"
            @places.each_with_index do |place, i|
              page << "addPlace(#{place.to_json}, #{i+1}, '#{dom_id(place)}')"
            end
            page << "map.zoomToPlaces()"
            page.replace_html :places, :partial => 'index_columns'
            page << "bindPlaceClicks()"
            page << "selectPlace('#{dom_id(@place)}')"
          end
        end
      end
    end
  end
  
  def search
    @q = params[:q]
    @places = Place.search(@q, :page => params[:page])
    if logged_in? && @places.blank?
      if ydn_places = GeoPlanet::Place.search(params[:q], :count => 5)
        new_places = ydn_places.map {|p| Place.import_by_woeid(p.woeid)}
        @places = Place.paginate(new_places.map(&:id).compact, :page => 1)
      end
    end
  end
  
  def show
    @listed_taxa = @place.listed_taxa.paginate(
      :page => 1, 
      :per_page => 11,
      :include => {:taxon => [:taxon_names, :flickr_photos, :iconic_taxon]},
      :conditions => "flickr_photos.id > 0",
      :group => 'listed_taxa.taxon_id',
      :order => "listed_taxa.id DESC"
    )
    
    # Load tips HTML
    @listed_taxa.map! do |listed_taxon|
      listed_taxon.taxon.html = render_to_string(:partial => 'taxa/taxon.html.erb', 
        :object => listed_taxon.taxon, :locals => {
          :image_options => {:size => 'small'},
          :link_image => true,
          :link_name => true,
          :include_image_attribution => true
      })
      listed_taxon
    end
    
    @children = @place.children.paginate(:page => 1, :order => 'name')
    observation_params = {
      :page => params[:page],
      :include => [:user, :taxon, :flickr_photos, :iconic_taxon]
    }
    if @place.swlat
      @observations = Observation.in_bounding_box(
        @place.swlat, @place.swlng, @place.nelat, @place.nelng).order_by(
        "observed_on DESC").paginate(observation_params)
    else
      @observations = Observation.near_point(
        @place.latitude, @place.longitude).order_by(
        "observed_on DESC").paginate(observation_params)
      # sphinx_options = {}
      # latrads = @place.latitude * (Math::PI / 180)
      # lngrads = @place.longitude * (Math::PI / 180)
      # sphinx_options[:geo] = [latrads, lngrads]
      # sphinx_options[:order] = "@geodist asc"
      # @observations = Observation.search('', sphinx_options)
    end
    
    # Get directions info
    ip = request.remote_ip
    # ip = '66.117.138.26' # Emeryville IP, for testing
    if GEOIP && (geoip_result = GeoipTools.city(ip))
      @directions_from = "#{geoip_result[:city]}, #{geoip_result[:state_code]}"
    end
    @directions_to = "#{@place.latitude}, #{@place.longitude}"
  end
  
  def new
    @place = Place.new
  end
  
  def create
    if params[:woeid]
      @place = Place.import_by_woeid(params[:woeid])
    else
      @place = Place.create(params[:place])
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
    @ydn_places = GeoPlanet::Place.search(params[:q], :count => 10)
    @places = @ydn_places.map {|ydnp| Place.new_from_geo_planet(ydnp)}
    
    respond_to do |format|
      format.json { render :json => @ydn_places }
      format.js do
        render :update do |page|
          page << "addPlaces(#{@places.to_json})"
          page['places'].replace_html :partial => 'create_external_place_links'
        end
      end
    end
  end
  
  def autocomplete
    @places = Place.paginate(:page => params[:page], 
      :conditions => ["display_name LIKE ?", "#{params[:q]}%"])
    render :layout => false, :partial => 'autocomplete'
  end
  
  def merge
    @place = Place.find_by_id(params[:id])
    @merge_target = Place.find_by_id(params[:with])
    
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
    conditions = params[:photos_only] ? "flickr_photos.id > 0" : nil
    listed_taxa = @place.listed_taxa.paginate(
      :page => params[:page], 
      :per_page => per_page,
      :include => {:taxon => [:iconic_taxon, :flickr_photos, :taxon_names]}, 
      :conditions => conditions, 
      :group => 'listed_taxa.taxon_id',
      :order => "listed_taxa.id DESC")
    @taxa = listed_taxa.map(&:taxon)
    
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
          :include => :flickr_photos, 
          :methods => [:image_url, :default_name, :common_name, 
            :scientific_name, :html])
      end
    end
  end
  
  
  private
  
  def load_place
    render_404 unless @place = Place.find_by_id(params[:id], 
      :include => [:check_list])
  end
  
  def filter_wikipedia_content
    # Find the TOC and delete it and all following
    if toc_pos = @decoded =~ /\<table id=\"toc/
      @decoded = @decoded[0...toc_pos]
    end
    
    # Delete anything that's not a <p>
    hhtml = Hpricot.parse(@decoded)
    hhtml.search('sup').remove
    hhtml.search('table').remove
    hhtml.search('ul').remove unless @decoded[0..100] =~ /refer to/
    hhtml = hhtml.search('p')
    
    @decoded = hhtml.to_s
    @decoded.gsub!(/\[\d+\]/, '')
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
        @places = Place.search(options.merge(
          :geo => [latrads,lonrads], 
          :order => "@geodist asc"))
        @places.delete_if {|p| p.id == @place.id}
      else
        @places = Place.search(@q, options.clone)
      end
    rescue ThinkingSphinx::ConnectionError
      @places = []
    end
  end
end
