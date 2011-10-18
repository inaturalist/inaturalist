class PlacesController < ApplicationController
  include Shared::WikipediaModule
  
  before_filter :login_required, :except => [:index, :show, :search, 
    :wikipedia, :taxa, :children, :autocomplete, :geometry]
  before_filter :return_here, :only => [:show]
  before_filter :load_place, :only => [:show, :edit, :update, :destroy, 
    :children, :taxa, :geometry]
  before_filter :limit_page_param_for_thinking_sphinx, :only => [:index, 
    :search]
  
  caches_page :geometry
  
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
    search_places_for_index(options) if @q
    
    @places = if @place && @places.size > 2
      @places.insert(2, @place)
    else
      @places.insert(0, @place)
    end.compact
    
    if @places.blank?
      if Rails.cache.exist?('random_place_ids')
        place_ids = Rails.cache.read('random_place_ids')
        @places = Place.all(:conditions => ["id in (?)", place_ids])
      else
        @places = Place.all(options.merge(:order => "RANDOM()"))
        Rails.cache.write('random_place_ids', @places.map(&:id), :expires_in => 1.day)
      end
    end
    @places = @places.compact
    
    @taxa_by_place_id = {}
    @places.each do |place|
      @taxa_by_place_id[place.id] = place.taxa.all(
        :limit => 6, 
        :include => [:photos, :taxon_names, :iconic_taxon],
        :order => "listed_taxa.id desc")
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
    search_for_places
    if @places.size == 1
      redirect_to @places.first
    end
  end
  
  def show
    if params[:test]
      show2
      return
    end
    # TODO this causes a temporary table sort, which == badness
    @listed_taxa = @place.listed_taxa.paginate(
      :page => 1,
      :per_page => 11,
      :select => "MAX(listed_taxa.id) AS id, listed_taxa.taxon_id",
      :joins => 
        "LEFT OUTER JOIN taxon_photos ON taxon_photos.taxon_id = listed_taxa.taxon_id " +
        "LEFT OUTER JOIN photos ON photos.id = taxon_photos.photo_id",
      :group => "listed_taxa.taxon_id",
      :order => "id DESC",
      :conditions => "photos.id IS NOT NULL"
    )
    @taxa = Taxon.all(:conditions => ["id IN (?)", @listed_taxa.map(&:taxon_id)],
      :include => [:photos, :taxon_names])
    

    # Load tips HTML
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
    
    begin
      @place_geometry = @place.place_geometry
    rescue ActiveRecord::StatementInvalid => e
      Rails.logger.error "[ERROR #{Time.now}] Broken geometry for place #{@place.id}: #{e}"
      HoptoadNotifier.notify(e, :request => request, :session => session)
    end

    @children = @place.children.paginate(:page => 1, :order => 'name')
    @observations = Observation.in_place(@place).order_by("observed_on DESC NULLS LAST").all(
      :include => [:user, :taxon, :photos, :iconic_taxon],
      :limit => 30
    )
    if @observations.blank? && @place.bounding_box
      @observations = Observation.in_bounding_box(*@place.bounding_box).
        order_by("observed_on DESC NULLS LAST").
        all(:include => [:user, :taxon, :photos, :iconic_taxon], :limit => 30)
    end
    
    @directions_to = "#{@place.latitude}, #{@place.longitude}"
  end
  
  def show2
    filter_param_keys = [:colors, :taxon, :page, :q]
    @filter_params = Hash[params.select{|k,v| 
      is_filter_param = filter_param_keys.include?(k.to_sym)
      is_blank = if v.is_a?(Array) && v.size == 1
        v[0].blank?
      else
        v.blank?
      end
      is_filter_param && !is_blank
    }].symbolize_keys
    scope = @place.taxa.scoped({})
    order = nil
    if @q = @filter_params[:q]
      @search_taxon_ids = Taxon.search_for_ids(@q, :per_page => 1000)
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
      scope = scope.descendants_of(@taxon)
      order = "ancestry, taxa.id"
    else
      scope = scope.has_photos
      order = "listed_taxa.observations_count DESC"
    end
    if @colors = @filter_params[:colors]
      scope = scope.colored(@colors)
    end
    if !@filter_params.blank? || !fragment_exist?(:action => "show", :action_suffix => "taxa_first_page")
      @taxa = scope.of_rank(Taxon::SPECIES).paginate(:select => "DISTINCT ON (ancestry, taxa.id) taxa.*", 
        :page => params[:page], :per_page => 50, 
        :include => [:taxon_names, :photos], 
        :order => order)
      @taxa_by_taxon_id = @taxa.index_by(&:id)
      @listed_taxa = @place.listed_taxa.all(
        :select => "DISTINCT ON (taxon_id) listed_taxa.*", 
        :conditions => ["taxon_id IN (?)", @taxa])
      @listed_taxa_by_taxon_id = @listed_taxa.index_by(&:taxon_id)
    end
    @distinct_listed_taxa_count = @place.listed_taxa.count(
      :select => "DISTINCT(taxon_id)", :joins => [:taxon], 
      :conditions => ["taxa.rank = ?", Taxon::SPECIES])
    @confirmed_listed_taxa_count = @place.listed_taxa.confirmed.count(
      :select => "DISTINCT(taxon_id)", :joins => [:taxon], 
      :conditions => ["taxa.rank = ?", Taxon::SPECIES])
    if logged_in?
      @current_user_observed_count = @place.listed_taxa.count(
        :joins => "JOIN listed_taxa ult ON ult.taxon_id = listed_taxa.taxon_id", 
        :conditions => ["ult.list_id = ?", current_user.life_list_id])
    end
    browsing_taxon_ids = Taxon::ICONIC_TAXA.map{|it| it.ancestor_ids + [it.id]}.flatten.uniq
    browsing_taxa = Taxon.all(:conditions => ["id in (?)", browsing_taxon_ids], :order => "ancestry", :include => [:taxon_names])
    browsing_taxa.delete_if{|t| t.name == "Life"}
    @arranged_taxa = Taxon.arrange_nodes(browsing_taxa)
    latrads = @place.latitude.to_f * (Math::PI / 180)
    lonrads = @place.longitude.to_f * (Math::PI / 180)
    render :action => "show2"
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
  
  def guide
    @taxon = Taxon.find_by_id(params[:taxon_id])
    @place = Place.find_by_id(params[:id])
    @month = params[:month]
    @month = Date.today.month if @month && @month.to_i < 1 || @month.to_i > 12
    @view = params[:view] || "grid"
    @view = "big grid" if @view == "grid"
    @view = "list guide" if @view == "guide"
    
    scope = if @place
      Observation.near_place(@place).scoped({})
    elsif params[:swlat]
      @coords = [params[:swlat], params[:swlng], params[:nelat], params[:nelng]].map do |c|
        c.to_f.round(2)
      end
      Observation.in_bounding_box(params[:swlat], params[:swlng], params[:nelat], params[:nelng]).scoped({})
    end
    
    if scope.blank?
      flash[:error] = "You must choose a place to show a guide."
      redirect_back_or_default(places_path)
      return
    end
    scope = scope.at_or_below_rank(Taxon::SPECIES)
    scope = scope.of(@taxon) if @taxon
    scope = scope.in_month(@month) if @month
    scope = scope.order_by("taxa.ancestry")
    
    if @month
      @counts = scope.count(:group => :taxon_id)
      taxon_ids = @counts.keys
    else
      @counts = scope.count(:group => "taxon_id || '-' || EXTRACT(MONTH FROM observed_on)")
      @counts.delete(nil)
      taxon_ids = []
      @month_counts = @counts.inject({}) do |memo, pair|
        unless pair[0].blank?
          Rails.logger.debug "[DEBUG] pair: #{pair.inspect}"
          taxon_id, month = pair[0].split('-')
          taxon_ids << taxon_id
          memo[taxon_id] ||= {}
          memo[taxon_id][month] = pair[1]
        end
        memo
      end
    end
    @taxa = Taxon.paginate(:page => params[:page], 
      :conditions => ["id IN (?)", taxon_ids],
      :order => "ancestry"
    )
    # TODO common-only: choose taxa from max to median obs counts
    # TODO inclide un-observed taxa from place check list
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
