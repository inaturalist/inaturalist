class TaxaController < ApplicationController
  caches_page :range, :if => Proc.new {|c| c.request.format.geojson?}
  caches_action :show, :expires_in => 1.day, :if => Proc.new {|c| 
    c.session.blank? || c.session[:user_id].blank?
  }
  caches_action :describe, :expires_in => 1.day, :if => Proc.new {|c| 
    c.session.blank? || c.session[:user_id].blank?
  }
  
  include TaxaHelper
  include Shared::WikipediaModule
  
  before_filter :return_here, :only => [:index, :show, :flickr_tagger, :curation]
  before_filter :login_required, :only => [:edit_photos, :update_photos, 
    :update_colors, :tag_flickr_photos, :tag_flickr_photos_from_observations,
    :flickr_photos_tagged, :add_places]
  before_filter :curator_required, :only => [:new, :create, :edit, :update,
    :destroy, :curation, :refresh_wikipedia_summary, :merge]
  before_filter :load_taxon, :only => [:edit, :update, :destroy, :photos, 
    :children, :graft, :describe, :edit_photos, :update_photos, :edit_colors,
    :update_colors, :add_places, :refresh_wikipedia_summary, :merge, 
    :observation_photos, :map, :range]
  before_filter :limit_page_param_for_thinking_sphinx, :only => [:index, 
    :browse, :search]
  
  before_filter :ensure_flickr_write_permission, :only => [
    :flickr_photos_tagged, :tag_flickr_photos, 
    :tag_flickr_photos_from_observations]
  verify :method => :post, :only => [:create, :update_photos, 
      :tag_flickr_photos, :tag_flickr_photos_from_observations],
    :redirect_to => { :action => :index }
  verify :method => :put, :only => [ :update, :update_colors ],
    :redirect_to => { :action => :index }
  cache_sweeper :taxon_sweeper, :only => [:update, :destroy, :update_photos]
  rescue_from ActionController::UnknownAction, :with => :try_show
  
  GRID_VIEW = "grid"
  LIST_VIEW = "list"
  BROWSE_VIEWS = [GRID_VIEW, LIST_VIEW]
  ALLOWED_SHOW_PARTIALS = %w(chooser)
  MOBILIZED = [:show, :index]
  before_filter :unmobilized, :except => MOBILIZED
  before_filter :mobilized, :only => MOBILIZED
  
  #
  # GET /observations
  # GET /observations.xml
  #
  # @param name: Return all taxa where name is an EXACT match
  # @param q:    Return all taxa where the name begins with q 
  #
  def index
    find_taxa unless request.format.html?
    
    begin
      @taxa.try(:total_entries)
    rescue ThinkingSphinx::SphinxError => e
      Rails.logger.error "[ERROR #{Time.now}] Failed sphinx search: #{e}"
      @taxa = WillPaginate::Collection.new(1,30,0)
    end
    
    respond_to do |format|
      format.html do # index.html.erb
        @featured_taxa = Taxon.all(:conditions => "featured_at IS NOT NULL", 
          :order => "featured_at DESC", :limit => 100,
          :include => [:iconic_taxon, :photos, :taxon_names])
        
        if @featured_taxa.blank?
          @featured_taxa = Taxon.all(:limit => 100, :conditions => [
            "taxa.wikipedia_summary IS NOT NULL AND " +
            "photos.id IS NOT NULL AND " +
            "taxa.observations_count > 1"
          ], :include => [:iconic_taxon, :photos, :taxon_names],
          :order => "taxa.id DESC")
        end
        
        # Shuffle the taxa (http://snippets.dzone.com/posts/show/2994)
        @featured_taxa = @featured_taxa.sort_by{rand}[0..10]
        
        flash[:notice] = @status unless @status.blank?
        if params[:q]
          find_taxa
          render :action => :search
        else
          @iconic_taxa = Taxon::ICONIC_TAXA
          @recent = Observation.all(
            :select => "DISTINCT ON (taxon_id) *",
            :from => "(SELECT * from observations WHERE taxon_id IS NOT NULL ORDER BY observed_on DESC NULLS LAST LIMIT 10) AS obs",
            :include => {:taxon => [:taxon_names]},
            :limit => 5
          ).sort_by(&:id).reverse
        end
      end
      format.mobile do
        if @taxa.blank?
          page = params[:page].to_i
          page = 1 if page < 1
          @taxon_photos = TaxonPhoto.paginate(:page => page, :per_page => 32, :order => "id DESC")
          @taxa = Taxon.all(:conditions => ["id IN (?)", @taxon_photos.map{|tp| tp.taxon_id}])
        end
      end
      format.xml  do
        render(:xml => @taxa.to_xml(
          :include => :taxon_names, :methods => [:common_name]))
      end
      format.json do
        @taxa = Taxon::ICONIC_TAXA if @taxa.blank? && params[:q].blank?
        render :json => @taxa.to_json(Taxon.default_json_options)
      end
    end
  end

  def show
    if params[:entry] == 'widget'
      flash[:notice] = "Welcome to iNat! Click 'Add an observtion' to the lower right. You'll be prompted to sign in/sign up if you haven't already"
    end
    @taxon ||= Taxon.find_by_id(params[:id].to_i, :include => [:taxon_names]) if params[:id]
    return render_404 unless @taxon
    
    if !@taxon.conservation_status.blank? && @taxon.conservation_status > Taxon::IUCN_LEAST_CONCERN
      @conservation_status_name = @taxon.conservation_status_name
      @conservation_status_source = @taxon.conservation_status_source
    end
    
    respond_to do |format|
      format.html do
        if @taxon.name == 'Life' && !@taxon.parent_id
          return redirect_to(:action => 'index')
        end
        
        @amphibiaweb = amphibiaweb_description?
        @try_amphibiaweb = try_amphibiaweb?
        
        @children = @taxon.children.all(:include => :taxon_names).sort_by{|c| c.name}
        @ancestors = @taxon.ancestors.all(:include => :taxon_names)
        @iconic_taxa = Taxon::ICONIC_TAXA
        
        @taxon_links = TaxonLink.for_taxon(@taxon).all(:include => :taxon)
        @taxon_links = @taxon_links.sort_by{|tl| tl.taxon.ancestry || ''}.reverse
        
        @check_listed_taxa = ListedTaxon.paginate(:page => 1,
          :include => [:place, :list],
          :conditions => ["place_id IS NOT NULL AND taxon_id = ?", @taxon]
        )
        @sorted_check_listed_taxa = @check_listed_taxa.sort_by{|lt| lt.place.place_type || 0}.reverse
        @places = @check_listed_taxa.map{|lt| lt.place}
        @countries = @taxon.places.all(
          :select => "places.id, place_type, code",
          :conditions => ["place_type = ?", Place::PLACE_TYPE_CODES['Country']]
        )
        if @countries.size == 1 && @countries.first.code == 'US'
          @us_states = @taxon.places.all(
            :select => "places.id, place_type, code",
            :conditions => [
              "place_type = ? AND parent_id = ?", Place::PLACE_TYPE_CODES['State'], 
              @countries.first.id
            ]
          )
        end
        @observations = Observation.of(@taxon).recently_added.all(:limit => 3)
        
        @photos = Rails.cache.fetch(@taxon.photos_cache_key) do
          @taxon.photos_with_backfill(:skip_external => true, :limit => 24)
        end
        
        if logged_in?
          @listed_taxa = ListedTaxon.all(
            :include => [:list],
            :conditions => [
              "lists.user_id = ? AND listed_taxa.taxon_id = ?", 
              current_user, @taxon
          ])
          @listed_taxa_by_list_id = @listed_taxa.index_by{|lt| lt.list_id}
          @current_user_lists = current_user.lists.all(:include => [:rules])
          @lists_rejecting_taxon = @current_user_lists.select do |list|
            if list.is_a?(LifeList)
              list.rules.map {|rule| rule.validates?(@taxon)}.include?(false)
            else
              false
            end
          end
        end
        
        @taxon_range = @taxon.taxon_ranges.without_geom.first
        @taxon_gbif = "#{@taxon.name.gsub(' ','+')}*"
        @show_range = @taxon_range
        @colors = @taxon.colors if @taxon.species_or_lower?
        
        render :action => 'show'
      end
      
      format.mobile do
        if @taxon.species_or_lower? && @taxon.species
          @siblings = @taxon.species.siblings.all(:limit => 100, :include => [:photos, :taxon_names]).sort_by{|t| t.name}
          @siblings.delete_if{|s| s.id == @taxon.id}
        else
          @children = @taxon.children.all(:limit => 100, :include => [:photos, :taxon_names]).sort_by{|t| t.name}
        end
      end
      
      format.xml do
        render :xml => @taxon.to_xml(
          :include => [:taxon_names, :iconic_taxon], 
          :methods => [:common_name]
        )
      end
      format.json do
        if (partial = params[:partial]) && ALLOWED_SHOW_PARTIALS.include?(partial)
          @taxon.html = render_to_string(:partial => "#{partial}.html.erb", :object => @taxon)
        end
        render(:json => @taxon.to_json(
          :include => [:taxon_names, :iconic_taxon], 
          :methods => [:common_name, :image_url, :html])
        )
      end
      format.node { render :json => jit_taxon_node(@taxon) }
    end
  end

  def new
    @taxon = Taxon.new
  end

  def create
    @taxon = Taxon.new
    return unless presave
    @taxon.attributes = params[:taxon]
    @taxon.creator = current_user
    if @taxon.save
      flash[:notice] = 'Taxon was successfully created.'
      if locked_ancestor = @taxon.ancestors.locked.first
        flash[:notice] += " Heads up: you just added a descendant of a " + 
          "locked taxon (<a href='/taxa/#{locked_ancestor.id}'>" + 
          "#{locked_ancestor.name}</a>).  Please consider merging this " + 
          "into an existing taxon instead."
      end
      redirect_to :action => 'show', :id => @taxon
    else
      render :action => 'new'
    end
  end

  def edit
    descendant_options = {:joins => [:taxon], :conditions => @taxon.descendant_conditions}
    taxon_options = {:conditions => {:taxon_id => @taxon}}
    @observations_exist = Observation.first(taxon_options) || Observation.first(descendant_options)
    @listed_taxa_exist = ListedTaxon.first(taxon_options) || ListedTaxon.first(descendant_options)
    @identifications_exist = Identification.first(taxon_options) || Identification.first(descendant_options)
    @descendants_exist = @taxon.descendants.first
    @taxon_range = TaxonRange.without_geom.first(:conditions => {:taxon_id => @taxon})
  end

  def update
    return unless presave
    if @taxon.update_attributes(params[:taxon])
      flash[:notice] = 'Taxon was successfully updated.'
      if locked_ancestor = @taxon.ancestors.locked.first
        flash[:notice] += " Heads up: you just added a descendant of a " + 
          "locked taxon (<a href='/taxa/#{locked_ancestor.id}'>" + 
          "#{locked_ancestor.name}</a>).  Please consider merging this " + 
          "into an existing taxon instead."
      end
      redirect_to taxon_path(@taxon)
      return
    else
      render :action => 'edit'
    end
  end

  def destroy
    @taxon.destroy
    flash[:notice] = "Taxon deleted."
    redirect_to :action => 'index'
  end
  

## Custom actions ############################################################
  
  # /taxa/browse?q=bird
  # /taxa/browse?q=bird&places=1,2&colors=4,5
  # TODO: /taxa/browse?q=bird&places=usa-ca-berkeley,usa-ct-clinton&colors=blue,black
  def search
    @q = params[:q].to_s
    match_mode = :all
    
    # Wrap the query in modifiers to ensure exact matches show first
    if @q.blank?
      q = @q
    else
      q = sanitize_sphinx_query(@q)
      q = "\"^#{q}$\" | #{q}"
      match_mode = :extended
    end
    drill_params = {}
    
    if params[:taxon_id] && (@taxon = Taxon.find_by_id(params[:taxon_id].to_i))
      drill_params[:ancestors] = @taxon.id
    end
    
    if params[:iconic_taxa] && @iconic_taxa_ids = params[:iconic_taxa].split(',')
      @iconic_taxa_ids = @iconic_taxa_ids.map(&:to_i)
      @iconic_taxa = Taxon.find(@iconic_taxa_ids)
      drill_params[:iconic_taxon_id] = @iconic_taxa_ids
    end
    # if params[:places] && @place_ids = params[:places].split(',')
    #   @place_ids = @place_ids.map(&:to_i)
    #   @places = Place.find(@place_ids)
    #   drill_params[:places] = @place_ids
    # end
    if params[:colors] && @color_ids = params[:colors].split(',')
      @color_ids = @color_ids.map(&:to_i)
      @colors = Color.find(@color_ids)
      drill_params[:colors] = @color_ids
    end
    
    per_page = params[:per_page] ? params[:per_page].to_i : 24
    per_page = 100 if per_page > 100
    
    unless @q.blank? && drill_params.blank?
      page = params[:page] ? params[:page].to_i : 1
      @facets = Taxon.facets(q, :page => page, :per_page => per_page,
        :with => drill_params, 
        :include => [:taxon_names, :photos],
        :field_weights => {:name => 2},
        :match_mode => match_mode)

      if @facets[:iconic_taxon_id]
        @faceted_iconic_taxa = Taxon.all(
          :conditions => ["id in (?)", @facets[:iconic_taxon_id].keys],
          :include => [:taxon_names, :photos]
        )
        @faceted_iconic_taxa = Taxon.sort_by_ancestry(@faceted_iconic_taxa)
        @faceted_iconic_taxa_by_id = @faceted_iconic_taxa.index_by(&:id)
      end

      if @facets[:colors]
        @faceted_colors = Color.all(:conditions => ["id in (?)", @facets[:colors].keys])
        @faceted_colors_by_id = @faceted_colors.index_by(&:id)
      end

      # if @facets[:places]
      #   @faceted_places = if @places.blank?
      #     Place.all(:order => "name", :conditions => [
      #       "id in (?) AND place_type = ?", @facets[:places].keys[0..50], Place::PLACE_TYPE_CODES['Country']
      #     ])
      #   else
      #     Place.all(:order => "name", :conditions => [
      #       "id in (?) AND parent_id IN (?)", 
      #       @facets[:places].keys, @places.map(&:id)
      #     ])
      #   end
      #   @faceted_places_by_id = @faceted_places.index_by(&:id)
      # end
      @taxa = @facets.for(drill_params)
    end
    
    begin
      @taxa.blank?
    rescue ThinkingSphinx::SphinxError, Riddle::OutOfBoundsError => e
      Rails.logger.error "[ERROR #{Time.now}] Failed sphinx search: #{e}"
      @taxa = WillPaginate::Collection.new(1,30,0)
    end
    
    do_external_lookups
    
    respond_to do |format|
      format.html do
        @view = BROWSE_VIEWS.include?(params[:view]) ? params[:view] : GRID_VIEW
        flash[:notice] = @status unless @status.blank?
        
        if @taxa.blank?
          @all_iconic_taxa = Taxon::ICONIC_TAXA
          @all_colors = Color.all
        end
        
        if params[:partial]
          render :partial => "taxa/#{params[:partial]}.html.erb", :locals => {
            :js_link => params[:js_link]
          }
        else
          render :browse
        end
      end
      format.json do
        options = Taxon.default_json_options
        options[:include].merge!(
          :iconic_taxon => {:only => [:id, :name]}, 
          :taxon_names => {:only => [:id, :name, :lexicon]}
        )
        options[:methods] += [:common_name, :image_url, :default_name]
        render :json => @taxa.to_json(options)
      end
    end
  end
  
  def autocomplete
    @q = params[:q] || params[:term]
    @taxon_names = TaxonName.paginate(
      :page => params[:page], 
      :include => [:taxon],
      :conditions => ["lower(name) LIKE ?", "#{@q.to_s.downcase}%"]
    )
    @taxa = @taxon_names.map do |taxon_name|
      taxon = taxon_name.taxon
      taxon.html = render_to_string(:partial => "chooser.html.erb", 
        :object => taxon, :comname => taxon_name.is_scientific_names? ? nil : taxon_name)
      taxon
    end
    respond_to do |format|
      format.json do
        render :json => @taxa.to_json(:methods => [:html])
      end
    end
  end
  
  def browse
    redirect_to :action => "search"
  end
  
  def occur_in
    @taxa = Taxon.occurs_in(params[:swlng], params[:swlat], params[:nelng], 
                            params[:nelat], params[:startDate], params[:endDate])
    @taxa.sort! do |a,b| 
      (a.common_name ? a.common_name.name : a.name) <=> (b.common_name ? b.common_name.name : b.name)
    end
    respond_to do |format|
      format.html
      format.json do
        render :text => @taxa.to_json(
                 :methods => [:id, :common_name] )
      end
    end
  end
  
  #
  # List child taxa of this taxon
  #
  def children
    respond_to do |format|
      format.html { redirect_to taxon_path(@taxon) }
      format.xml do
        render :xml => @taxon.children.to_xml(
                :include => :taxon_names, :methods => [:common_name] )
      end
      format.json do
        options = Taxon.default_json_options
        options[:include].merge!(:taxon_names => {:only => [:id, :name, :lexicon]})
        options[:methods] += [:common_name]
        render :json => @taxon.children.all(:include => [{:taxon_photos => :photo}, :taxon_names]).to_json(options)
      end
    end
  end
  
  def photos
    limit = params[:limit].to_i
    limit = 24 if limit.blank? || limit == 0
    limit = 50 if limit > 50
    
    begin
      @photos = Rails.cache.fetch(@taxon.photos_with_external_cache_key) do
        @taxon.photos_with_backfill(:limit => 50).map do |fp|
          fp.api_response = nil
          fp
        end
      end[0..(limit-1)]
    rescue Timeout::Error => e
      Rails.logger.error "[ERROR #{Time.now}] Timeout: #{e}"
      # HoptoadNotifier.notify(e, :request => request, :session => session)
      @photos = @taxon.photos
    end
    if params[:partial]
      key = {:controller => 'taxa', :action => 'photos', :id => @taxon.id, :partial => params[:partial]}
      if fragment_exist?(key)
        content = read_fragment(key)
      else
        content = if @photos.blank?
          '<div class="description">No matching photos.</div>'
        else
          render_to_string :partial => "taxa/#{params[:partial]}", :collection => @photos
        end
        write_fragment(key, content)
      end
      render :layout => false, :text => content
    else
      render :layout => false, :partial => "photos", :locals => {
        :photos => @photos
      }
    end
  rescue SocketError => e
    raise unless Rails.env.development?
    Rails.logger.debug "[DEBUG] Looks like you're offline, skipping flickr"
    render :text => "You're offline."
  end
  
  def map
    @taxon_range = @taxon.taxon_ranges.without_geom.first
    if params[:place_id] && (@place = Place.find_by_id(params[:place_id]))
      @place_geometry = PlaceGeometry.without_geom.first(:conditions => {:place_id => @place.id})
    end
    @bounds = if @place && (bbox = @place.bounding_box)
      GeoRuby::SimpleFeatures::Envelope.from_points([
        Point.from_coordinates([bbox[1], bbox[0]]), 
        Point.from_coordinates([bbox[3], bbox[2]])
      ])
    elsif @taxon_range
      @taxon.taxon_ranges.calculate(:extent, :geom)
    else
      Observation.of(@taxon).calculate(:extent, :geom)
    end
    if @bounds
      @extent = [
        {:lon => @bounds.lower_corner.x, :lat => @bounds.lower_corner.y}, 
        {:lon => @bounds.upper_corner.x, :lat => @bounds.upper_corner.y}
      ]
    end
    
    @cloudmade_key = INAT_CONFIG['cloudmade'].try(:[], 'key')
    @bing_key = INAT_CONFIG['bing'].try(:[], 'key')
    
    find_options = {
      :select => "listed_taxa.id, place_id, last_observation_id, places.place_type, occurrence_status_level, establishment_means", 
      :joins => [:place], 
      :conditions => [
        "place_id IS NOT NULL AND places.place_type = ?", 
        Place::PLACE_TYPE_CODES['County']
      ]
    }
    @county_listings = @taxon.listed_taxa.all(find_options).index_by{|lt| lt.place_id}
    find_options[:conditions][1] = Place::PLACE_TYPE_CODES['State']
    @state_listings = @taxon.listed_taxa.all(find_options).index_by{|lt| lt.place_id}
    find_options[:conditions][1] = Place::PLACE_TYPE_CODES['Country']
    @country_listings = @taxon.listed_taxa.all(find_options).index_by{|lt| lt.place_id}
    
    if params[:test]
      @child_taxa = @taxon.descendants.of_rank(Taxon::SPECIES).all(:limit => 10)
      @child_taxon_ranges = TaxonRange.without_geom.all(:conditions => ["taxon_id IN (?)", @child_taxa]).group_by(&:taxon_id)
      @children = @child_taxa.map do |child|
        {
          :id => child.id, 
          :range_url => @child_taxon_ranges[child.id] ? taxon_range_geom_url(child.id, :format => "geojson") : nil, 
          :observations_url => observations_of_url(child, :format => "geojson"),
          :name => child.name
        }
      end
    end
  end
  
  def range
    @taxon_range = if request.format.geojson?
      @taxon.taxon_ranges.simplified.first
    else
      @taxon.taxon_ranges.first
    end
    unless @taxon_range
      flash[:error] = "Taxon doesn't have a range"
      redirect_to @taxon
      return
    end
    respond_to do |format|
      format.html { redirect_to taxon_map_path(@taxon) }
      format.kml { redirect_to @taxon_range.range.url }
      format.geojson { render :json => [@taxon_range].to_geojson }
    end
  end
  
  def observation_photos
    if per_page = params[:per_page]
      per_page = per_page.to_i > 50 ? 50 : per_page.to_i
    end
    observations = if params[:q].blank?
      Observation.of(@taxon).paginate(:page => params[:page], 
        :per_page => per_page, :include => [:photos], 
        :conditions => "photos.id IS NOT NULL")
    else
      Observation.search(params[:q], :page => params[:page], 
      :per_page => per_page, :with => {:has_photos => true, :taxon_id => @taxon.id})
    end
    @photos = observations.map(&:photos).flatten
    render :partial => 'photos/photo_list_form', :locals => {
      :photos => @photos, 
      :index => params[:index],
      :local_photos => false }
  end
  
  def edit_photos
    render :layout => false
  end
  
  def add_places
    unless params[:tab].blank?
      @places = case params[:tab]
      when 'countries'
        @countries = Place.all(:order => "name",
          :conditions => ["place_type = ?", Place::PLACE_TYPE_CODES["Country"]]).compact
      when 'us_states'
        if @us = Place.find_by_name("United States")
          @us.children.all(:order => "name", :include => :parent).compact
        else
          []
        end
      else
        []
      end
      
      @listed_taxa = @taxon.listed_taxa.all(:conditions => ["place_id IN (?)", @places], 
        :select => "DISTINCT ON (place_id) listed_taxa.*")
      @listed_taxa_by_place_id = @listed_taxa.index_by(&:place_id)
      
      render :partial => 'taxa/add_to_place_link', :collection => @places, :locals => {
        :skip_map => true
      }
      return
    end
    
    if request.post?
      if params[:paste_places]
        place_names = params[:paste_places].split(",").map{|p| p.strip.downcase}.reject(&:blank?)
        @places = Place.all(:conditions => [
          "place_type = ? AND name IN (?)", 
          Place::PLACE_TYPE_CODES['Country'], place_names
        ])
        @places ||= []
        (place_names - @places.map{|p| p.name.strip.downcase}).each do |new_place_name|
          ydn_places = GeoPlanet::Place.search(new_place_name, :count => 1, :type => "Country")
          next if ydn_places.blank?
          @places << Place.import_by_woeid(ydn_places.first.woeid)
        end
        
        @listed_taxa = @places.map do |place| 
          place.check_list.add_taxon(@taxon, :user_id => current_user.id)
        end.select(&:valid?)
        @listed_taxa_by_place_id = @listed_taxa.index_by(&:place_id)
        
        render :update do |page|
          if @places.blank?
            page[dom_id(@taxon, 'place_selector_paste_places')].replace_html(
              content_tag(:p, "No countries matching \"#{place_names.join(', ')}\"", :class => "description")
            )
          else
            page[dom_id(@taxon, 'place_selector_paste_places')].replace_html(
              :partial => 'add_to_place_link', :collection => @places)
          end
        end
        return
      end
      
      search_for_places
      @listed_taxa = @taxon.listed_taxa.all(:conditions => ["place_id IN (?)", @places], 
        :select => "DISTINCT ON (place_id) listed_taxa.*")
      @listed_taxa_by_place_id = @listed_taxa.index_by(&:place_id)
      render :update do |page|
        if @places.blank?
          page[dom_id(@taxon, 'place_selector_places')].replace_html(
            content_tag(:p, "No places matching \"#{@q}\"", :class => "description")
          )
        else
          page[dom_id(@taxon, 'place_selector_places')].replace_html(
            :partial => 'add_to_place_link', :collection => @places)
        end
      end
      return
    end
    
    render :layout => false
  end
  
  def find_places
    @limit = 5
    @js_link = params[:js_link]
    @partial = params[:partial]
    search_for_places
    render :layout => false
  end
  
  def update_photos
    photos = retrieve_photos
    @taxon.photos = photos
    @taxon.save
    unless photos.count == 0
      Taxon.send_later(:update_ancestor_photos, @taxon.id, photos.first.id, :dj_priority => 2)
    end
    flash[:notice] = "Taxon photos updated!"
    redirect_to taxon_path(@taxon)
  rescue Errno::ETIMEDOUT
    flash[:error] = "Request timed out!"
    redirect_back_or_default(taxon_path(@taxon))
  rescue Koala::Facebook::APIError => e
    raise e unless e.message =~ /OAuthException/
    flash[:error] = "Facebook needs the owner of that photo to re-confirm their connection to iNat."
    redirect_back_or_default(taxon_path(@taxon))
  end
  
  def describe
    @amphibiaweb = amphibiaweb_description?
    if @amphibiaweb
      taxon_names = @taxon.taxon_names.all(
        :conditions => {:lexicon => TaxonName::LEXICONS[:SCIENTIFIC_NAMES]}, 
        :order => "is_valid, id desc")
      if @xml = get_amphibiaweb(taxon_names)
        render :partial => "amphibiaweb"
        return
      else
        @before_wikipedia = '<div class="notice status">AmphibiaWeb didn\'t have info on this taxon, showing Wikipedia instead.</div>' 
      end
    end
    
    
    @title = @taxon.wikipedia_title.blank? ? @taxon.name : @taxon.wikipedia_title
    wikipedia
  end
  
  def refresh_wikipedia_summary
    begin
      summary = @taxon.set_wikipedia_summary
    rescue Timeout::Error => e
      error_text = e.message
    end
    unless summary.blank?
      render :text => summary
    else
      error_text ||= "Could't retrieve the Wikipedia " + 
        "summary for #{@taxon.name}.  Make sure there is actually a " + 
        "corresponding article on Wikipedia."
      render :status => 404, :text => error_text
    end
  end
  
  def update_colors
    unless params[:taxon] && params[:taxon][:color_ids]
      redirect_to @taxon
    end
    params[:taxon][:color_ids].delete_if(&:blank?)
    @taxon.colors = Color.find(params[:taxon].delete(:color_ids))
    respond_to do |format|
      if @taxon.save
        format.html { redirect_to @taxon }
        format.js do
          render :text => "Colors updated."
        end
      else
        format.html do
          flash[:error] = "There was a problem saving those colors: " +
            @taxon.errors.full_messages.join(', ')
          redirect_to @taxon
        end
        format.js do
          render :update do |page|
            page.alert "There were some problems saving those colors: " +
              @taxon.errors.full_messages.join(', ')
          end
        end
      end
    end
  end
  
  
  def graft
    if @taxon.name_provider.blank?
      @error_message = "Sorry, you can only automatically graft taxa that " + 
        "were imported from an external name provider."
    else
      begin
        lineage = Ratatosk.graft(@taxon)
      rescue Timeout::Error => e
        @error_message = e.message
      rescue RatatoskGraftError => e
        @error_message = e.message
      end
      @taxon.reload
      @error_message = "Graft failed" unless @taxon.grafted?
    end
    
    respond_to do |format|
      format.html do
        flash[:error] = @error_message if @error_message
        redirect_to(edit_taxon_path(@taxon))
      end
      format.js do
        if @error_message
          render :status => :unprocessable_entity, :text => @error_message
        else
          render :text => "Taxon grafted to #{@taxon.parent.name}"
        end
      end
    end
  end
  
  def merge
    @keeper = Taxon.find_by_id(params[:taxon_id].to_i)
    if @keeper && @keeper.id == @taxon.id
      msg = "Failed to merge taxon #{@taxon.id} (#{@taxon.name}) into taxon #{@keeper.id} (#{@keeper.name}).  You can't merge a taxon with itself."
      respond_to do |format|
        format.html do
          flash[:error] = msg
          redirect_back_or_default(@taxon)
          return
        end
        format.js do
          render :text => msg, :status => :unprocessable_entity, :layout => false
          return
        end
      end
    end
    
    if request.post? && params[:commit] == "Merge"
      unless @keeper
        flash[:error] = "You must select a taxon to merge with."
        return redirect_to :action => "merge", :id => @taxon
      end
      
      if @taxon.id == @keeper_id
        flash[:error] = "Can't merge a taxon with itself."
        return redirect_to :action => "merge", :id => @taxon
      end
      
      @keeper.merge(@taxon)
      flash[:notice] = "#{@taxon.name} (#{@taxon.id}) merged into " + 
        "#{@keeper.name} (#{@keeper.id}).  #{@taxon.name} (#{@taxon.id}) " + 
        "has been deleted."
      redirect_to @keeper
      return
    end
    
    respond_to do |format|
      format.html
      format.js do
        render :partial => "taxa/merge"
      end
    end
  end
  
  def curation
    @flags = Flag.paginate(:page => params[:page], 
      :include => :user,
      :conditions => "resolved = false AND flaggable_type = 'Taxon'",
      :order => "flags.id desc")
    @resolved_flags = Flag.all(:limit => 5, 
      :include => [:user, :resolver],
      :conditions => "resolved = true AND flaggable_type = 'Taxon'",
      :order => "flags.id desc")
    life = Taxon.find_by_name('Life')
    @ungrafted = Taxon.roots.paginate(:conditions => ["id != ?", life], 
      :page => 1, :per_page => 100, :include => [:taxon_names])
  end
  
  def flickr_tagger    
    net_flickr = get_net_flickr
    if logged_in? && current_user.flickr_identity
      net_flickr.auth.token = current_user.flickr_identity.token
    end
    
    @taxon ||= Taxon.find_by_id(params[:id].to_i) if params[:id]
    @taxon ||= Taxon.find_by_id(params[:taxon_id].to_i) if params[:taxon_id]
    
    @flickr_photo_ids = [params[:flickr_photo_id], params[:flickr_photos]].flatten.compact
    @flickr_photos = @flickr_photo_ids.map do |flickr_photo_id|
      begin
        original = net_flickr.photos.get_info(flickr_photo_id)
        flickr_photo = FlickrPhoto.new_from_net_flickr(original)
        if flickr_photo && @taxon.blank?
          if @taxa = flickr_photo.to_taxa
            @taxon = @taxa.sort_by{|t| t.ancestry || ''}.last
          end
        end
        flickr_photo
      rescue Net::Flickr::APIError
        flash[:notice] = "Sorry, one of those Flickr photos either doesn't exist or " +
          "you don't have permission to view it."
        nil
      end
    end.compact
    
    @tags = @taxon ? @taxon.to_tags : []
    
    respond_to do |format|
      format.html
      format.json { render :json => @tags}
    end
  end
  
  def tag_flickr_photos
    # Post tags to flickr
    if params[:flickr_photos].blank?
      flash[:notice] = "You didn't select any photos to tag!"
      redirect_to :action => 'flickr_tagger' and return
    end
    
    unless logged_in? && current_user.flickr_identity
      flash[:notice] = "Sorry, you need to be signed in and have a " + 
        "linked Flickr account to post tags directly to Flickr."
      redirect_to :action => 'flickr_tagger' and return
    end
    
    get_flickraw
    
    params[:flickr_photos].each do |flickr_photo_id|
      tag_flickr_photo(flickr_photo_id, params[:tags])
      return redirect_to :action => "flickr_tagger" unless flash[:error].blank?
    end
    
    flash[:notice] = "Your photos have been tagged!"
    redirect_to :action => 'flickr_photos_tagged', 
      :flickr_photos => params[:flickr_photos], :tags => params[:tags]
  end
  
  def tag_flickr_photos_from_observations
    if params[:o].blank?
      flash[:error] = "You didn't select any observations."
      return redirect_to :back
    end
    
    @observations = current_user.observations.all(
      :conditions => ["id IN (?)", params[:o].split(',')],
      :include => [:photos, {:taxon => :taxon_names}]
    )
    
    if @observations.blank?
      flash[:error] = "No observations matching those IDs."
      return redirect_to :back
    end
    
    if @observations.map(&:user_id).uniq.size > 1 || @observations.first.user_id != current_user.id
      flash[:error] = "You don't have permission to edit those photos."
      return redirect_to :back
    end
    
    get_flickraw
    
    flickr_photo_ids = []
    @observations.each do |observation|
      observation.photos.each do |photo|
        next unless photo.is_a?(FlickrPhoto)
        next unless observation.taxon
        tag_flickr_photo(photo.native_photo_id, observation.taxon.to_tags)
        unless flash[:error].blank?
          return redirect_to :back
        end
        flickr_photo_ids << photo.native_photo_id
      end
    end
    
    redirect_to :action => 'flickr_photos_tagged', :flickr_photos => flickr_photo_ids
  end
  
  def flickr_photos_tagged
    get_flickraw
    
    @tags = params[:tags]
    
    if params[:flickr_photos].blank?
      flash[:error] = "No Flickr photos tagged!"
      return redirect_to :action => "flickr_tagger"
    end
    
    @flickr_photos = params[:flickr_photos].map do |flickr_photo_id|
      fp = flickr.photos.getInfo(:photo_id => flickr_photo_id, 
        :auth_token => current_user.flickr_identity.token)
      FlickrPhoto.new_from_flickraw(fp, :user => current_user)
    end

    
    @observations = current_user.observations.all(
      :include => :photos,
      :conditions => [
        "photos.native_photo_id IN (?) AND photos.type = ?", 
        @flickr_photos.map(&:native_photo_id), FlickrPhoto.to_s
      ]
    )
    @observations_by_native_photo_id = {}
    @observations.each do |observation|
      observation.photos.each do |flickr_photo|
        @observations_by_native_photo_id[flickr_photo.native_photo_id] = observation
      end
    end
  end
  
  def tree
    @taxon = Taxon.find_by_id(params[:id], :include => [:taxon_names, :photos])
    @taxon ||= Taxon.find_by_id(params[:taxon_id].to_i, :include => [:taxon_names, :photos])
    unless @taxon
      @taxon = Taxon.find_by_name('Life')
      @taxon ||= Taxon.iconic_taxa.first.parent
    end
    @iconic_taxa = Taxon::ICONIC_TAXA
  end
  
## Protected / private actions ###############################################
  private
  
  def find_taxa
    find_options = {
      :order => "#{Taxon.table_name}.name ASC",
      :include => :taxon_names
    }
    
    @qparams = {}
    if params[:q]
      @qparams[:q] = params[:q]
      find_options[:conditions] =  [ "#{Taxon.table_name}.name LIKE ?", 
                                      '%' + params[:q].split(' ').join('%') + '%' ]
    elsif params[:name]
      @qparams[:name] = params[:name]
      find_options[:conditions] = [ "name = ?", params[:name] ]
    else
      find_options[:conditions] = ["is_iconic = ?", true]
      find_options[:order] = :ancestry
    end
    if params[:limit]
      @qparams[:limit] = params[:limit]
      find_options[:limit] = params[:limit]
    else
      params[:page_size] ||= 10
      params[:page] ||= 1
      find_options[:page] = params[:page]
      find_options[:per_page] = params[:page_size]
    end
    if params[:all_names] == 'true'
      @qparams[:all_names] = params[:all_names]
      find_options[:include] = [:taxon_names]
      if find_options[:conditions]
        find_options[:conditions][0] += " OR #{TaxonName.table_name}.name LIKE ?"
        find_options[:conditions] << ('%' + params[:q].split(' ').join('%') + '%')
      else
        find_options[:conditions] =  [ "#{TaxonName.table_name}.name LIKE ?", 
                                        '%' + params[:q].split(' ').join('%') + '%' ]
      end
    end
    
    @taxa = Taxon.paginate(find_options)
    do_external_lookups
  end
  
  def retrieve_photos
    [retrieve_remote_photos, retrieve_local_photos].flatten.compact
  end
  
  def retrieve_remote_photos
    photo_classes = Photo.descendent_classes - [LocalPhoto]
    photos = []
    photo_classes.each do |photo_class|
      param = photo_class.to_s.underscore.pluralize
      next if params[param].blank?
      params[param].reject {|i| i.blank?}.uniq.each do |photo_id|
        if fp = photo_class.find_by_native_photo_id(photo_id)
          photos << fp 
        else
          pp = photo_class.get_api_response(photo_id)
          photos << photo_class.new_from_api_response(pp)
        end
      end
    end
    photos
  end
  
  def retrieve_local_photos
    return [] if params[:local_photos].nil?
    photos = []
    params[:local_photos].reject {|i| i.empty?}.uniq.each do |photo_id|
      if fp = LocalPhoto.find_by_native_photo_id(photo_id)
        photos << fp 
      end
    end
    photos
  end
  
  def load_taxon
    unless @taxon = Taxon.find_by_id(params[:id].to_i, :include => :taxon_names)
      render_404
      return
    end
  end
  
  # Try to find a taxon from urls like /taxa/Animalia or /taxa/Homo_sapiens
  def try_show(exception)
    raise exception if params[:action].blank?
    name, format = params[:action].split('_').join(' ').split('.')
    request.format = format if request.format.blank? && !format.blank?
    name = name.to_s.downcase
    
    # Try to look by its current unique name
    unless @taxon
      begin
        taxa = Taxon.all(:conditions => ["unique_name = ?", name], :limit => 2) unless @taxon
      rescue ActiveRecord::StatementInvalid => e
        raise e unless e.message =~ /invalid byte sequence/
        name = Iconv.iconv('UTF8', 'LATIN1', name).first
        taxa = Taxon.all(:conditions => ["unique_name = ?", name], :limit => 2)
      end
      @taxon = taxa.first if taxa.size == 1
    end
    
    # Try to look by its current scientifc name
    unless @taxon
      begin
        taxa = Taxon.all(:conditions => ["lower(name) = ?", name], :limit => 2) unless @taxon
      rescue ActiveRecord::StatementInvalid => e
        raise e unless e.message =~ /invalid byte sequence/
        name = Iconv.iconv('UTF8', 'LATIN1', name)
        taxa = Taxon.all(:conditions => ["lower(name) = ?", name], :limit => 2)
      end
      @taxon = taxa.first if taxa.size == 1
    end
    
    # Try to find a unique TaxonName
    unless @taxon
      begin
        taxon_names = TaxonName.all(:conditions => ["lower(name) = ?", name], :limit => 2)
      rescue ActiveRecord::StatementInvalid => e
        raise e unless e.message =~ /invalid byte sequence/
        name = Iconv.iconv('UTF8', 'LATIN1', name)
        taxon_names = TaxonName.all(:conditions => ["lower(name) = ?", name], :limit => 2)
      end
      if taxon_names.size == 1
        @taxon = taxon_names.first.taxon
        
        # Redirect to the currently accepted sciname if this isn't an accepted sciname
        unless taxon_names.first.is_valid?
          return redirect_to :action => @taxon.name.split.join('_')
        end
      end
    end
    
    # Redirect to a canonical form
    if @taxon
      canonical = (@taxon.unique_name || @taxon.name).split.join('_')
      taxon_names ||= @taxon.taxon_names.all
      acceptable_names = [@taxon.unique_name, @taxon.name].compact.map{|n| n.split.join('_')} + 
        taxon_names.map{|tn| tn.name.split.join('_')}
      unless acceptable_names.include?(params[:action])
        redirect_target = if params[:action].to_s.split.join('_') == @taxon.name.split.join('_')
          @taxon.name.split.join('_')
        else
          canonical
        end
        return redirect_to :action => redirect_target
      end
    end
    
    # TODO: if multiple exact matches, render a disambig page with status 300 (Mulitple choices)
    unless @taxon
      # TODO: render custom 404 page with search & import options
      return redirect_to :action => 'search', :q => name
    else
      return_here
      show
    end
  end
  
  def do_external_lookups
    return unless logged_in?
    return unless params[:force_external] || (params[:include_external] && @taxa.blank?)
    @external_taxa = []
    logger.info("DEBUG: Making an external lookup...")
    begin
      ext_names = TaxonName.find_external(params[:q], :src => params[:external_src])
    rescue Timeout::Error, NameProviderError => e
      @status = e.message
      return
    end
    
    @external_taxa = Taxon.find(ext_names.map(&:taxon_id)) unless ext_names.blank?
    
    return if @external_taxa.blank?
    
    # graft in the background
    @external_taxa.each do |external_taxon|
      external_taxon.send_later(:graft) unless external_taxon.grafted?
    end
    
    @taxa = WillPaginate::Collection.create(1, @external_taxa.size) do |pager|
      pager.replace(@external_taxa)
      pager.total_entries = @external_taxa.size
    end
  end
  
  def tag_flickr_photo(flickr_photo_id, tags)
    # Strip and enclose multiword tags in quotes
    if tags.is_a?(Array)
      tags = tags.map do |t|
        t.strip.match(/\s+/) ? "\"#{t.strip}\"" : t.strip
      end.join(' ')
    end
    
    begin
      flickr.photos.addTags(:photo_id => flickr_photo_id, 
        :tags => tags, 
        :auth_token => current_user.flickr_identity.token)
    rescue FlickRaw::FailedResponse => e
      if e.message =~ /Insufficient permissions/
        auth_url = FlickRaw.auth_url :perms => 'write'
        flash[:error] = "iNat can't add tags to your photos until " + 
          "Flickr knows you've given us permission.  " + 
          "<a href=\"#{auth_url}\">Click here to authorize iNat to add tags</a>."
      else
        flash[:error] = "Something went wrong trying to to post those tags: #{e.message}"
      end
    rescue Exception => e
      flash[:error] = "Something went wrong trying to to post those tags: #{e.message}"
    end
  end
  
  def presave
    @taxon.photos = retrieve_photos
    if params[:taxon_names]
      TaxonName.update(params[:taxon_names].keys, params[:taxon_names].values)
    end
    if params[:taxon][:colors]
      @taxon.colors = Color.find(params[:taxon].delete(:colors))
    end
    
    unless params[:taxon][:parent_id].blank?
      unless Taxon.exists?(params[:taxon][:parent_id].to_i)
        flash[:error] = "That parent taxon doesn't exist (try a different ID)"
        render :action => 'edit'
        return false
      end
    end
    
    # Set the last editor
    params[:taxon].update(:updater_id => current_user.id)
    
    # Anyone who's allowed to create or update should be able to skip locks
    params[:taxon].update(:skip_locks => true)
    
    if params[:taxon][:featured_at] && params[:taxon][:featured_at] == "1"
      params[:taxon][:featured_at] = Time.now
    else
      params[:taxon][:featured_at] = ""
    end
    true
  end
  
  def amphibiaweb_description?
    params[:description] != 'wikipedia' && try_amphibiaweb?
  end
  
  def try_amphibiaweb?
    @taxon.species_or_lower? && 
      @taxon.ancestor_ids.include?(Taxon::ICONIC_TAXA_BY_NAME['Amphibia'].id)
  end
  
  # Temp method for fetching amphibiaweb desc.  Will probably implement this 
  # through TaxonLinks eventually
  def get_amphibiaweb(taxon_names)
    taxon_name = taxon_names.pop
    return unless taxon_name
    @genus_name, @species_name = taxon_name.name.split
    url = "http://amphibiaweb.org/cgi/amphib_ws?where-genus=#{@genus_name}&where-species=#{@species_name}&src=eol"
    Rails.logger.info "[INFO #{Time.now}] AmphibiaWeb request: #{url}"
    xml = Nokogiri::XML(open(url))
    if xml.blank? || xml.at(:error)
      get_amphibiaweb(taxon_names)
    else
      xml
    end
  end
  
  def ensure_flickr_write_permission
    @provider_authorization = current_user.provider_authorizations.first(:conditions => {:provider_name => 'flickr'})
    if @provider_authorization.blank? || @provider_authorization.scope != 'write'
      session[:return_to] = request.get? ? request.request_uri : request.env['HTTP_REFERER']
      redirect_to auth_url_for('flickr', :scope => 'write')
      return false
    end
  end
end
