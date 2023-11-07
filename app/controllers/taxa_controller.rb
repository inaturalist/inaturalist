#encoding: utf-8
class TaxaController < ApplicationController
  caches_page :range, :if => Proc.new {|c| c.request.format == :geojson}
  # taxa/show includes a CSRF token, which means you might see someone else's
  # token while signed out, which makes it impossible to update the session. I
  # want to see how we do without this. If we need caching, we need to be more
  # selective than caching the entire page. ~~~kueda 20211019
  # caches_action :show, :expires_in => 1.day,
  #   :cache_path => Proc.new{ |c| {
  #     locale: I18n.locale,
  #     ssl: c.request.ssl? } },
  #   :if => Proc.new {|c|
  #     !request.format.json? &&
  #     ( c.session.blank? || c.session['warden.user.user.key'].blank? ) &&
  #     c.params[:test].blank?
  #   }

  caches_action :show, expires_in: 1.day,
    cache_path: Proc.new{ |c| {
      locale: I18n.locale,
      only_path: true
    } },
    if: Proc.new {|c| request.format.json? }

  before_action :allow_external_iframes, only: [:map]
  
  include TaxaHelper
  include Shared::WikipediaModule
  
  before_action :return_here, :only => [:index, :show, :flickr_tagger, :curation, :synonyms, :browse_photos]
  before_action :authenticate_user!, :only => [:update_photos,
    :set_photos,
    :update_colors, :tag_flickr_photos, :tag_flickr_photos_from_observations,
    :flickr_photos_tagged, :synonyms]
  before_action :curator_required, :only => [:new, :create, :edit, :update,
    :destroy, :curation, :refresh_wikipedia_summary, :merge, :synonyms, :graft]
  before_action :load_taxon, :only => [:edit, :update, :destroy, :photos, 
    :children, :graft, :describe, :update_photos, :set_photos, :edit_colors,
    :update_colors, :refresh_wikipedia_summary, :merge, 
    :range, :schemes, :tip, :links, :map_layers, :browse_photos, :taxobox, :taxonomy_details,
    :history]
  before_action :taxon_curator_required, :only => [:edit, :update,
    :destroy, :merge, :graft]
  before_action :limit_page_param_for_search, :only => [:index,
    :browse, :search]
  before_action :ensure_flickr_write_permission, :only => [
    :flickr_photos_tagged, :tag_flickr_photos, 
    :tag_flickr_photos_from_observations]
  cache_sweeper :taxon_sweeper, :only => [:update, :destroy, :update_photos, :set_photos]

  prepend_around_action :enable_replica, only: [:describe, :links, :show]

  GRID_VIEW = "grid"
  LIST_VIEW = "list"
  BROWSE_VIEWS = [GRID_VIEW, LIST_VIEW]
  ALLOWED_SHOW_PARTIALS = %w( chooser )
  ALLOWED_PHOTO_PARTIALS = %w( photo )
  
  #
  # GET /observations
  # GET /observations.xml
  #
  # @param name: Return all taxa where name is an EXACT match
  # @param q:    Return all taxa where the name begins with q 
  #
  def index
    find_taxa unless request.format.blank? || request.format.html?
    
    begin
      @taxa.try( :total_entries )
    rescue => e
      Rails.logger.error "[ERROR] Taxon index failed: #{e}"
      @taxa = WillPaginate::Collection.new(1, 30, 0)
    end
    
    respond_to do |format|
      format.html do # index.html.erb
        @site_place = @site.place if @site
        @featured_taxa = Taxon.active.where("taxa.featured_at IS NOT NULL").
          order("taxa.featured_at DESC").
          limit(100)
        @featured_taxa = @featured_taxa.from_place(@site_place) if @site_place
        
        if @featured_taxa.blank?
          @featured_taxa = Taxon.limit(100).joins(:photos).where(
            "taxa.wikipedia_summary IS NOT NULL AND " +
            "photos.id IS NOT NULL AND " +
            "taxa.observations_count > 1"
          ).order("taxa.id DESC")
          @featured_taxa = @featured_taxa.from_place(@site_place) if @site_place
        end
        
        # Shuffle the taxa (http://snippets.dzone.com/posts/show/2994)
        @featured_taxa = @featured_taxa.sort_by{rand}[0..10]
        Taxon.preload_associations(@featured_taxa, [
          :iconic_taxon,
          { photos: [:user, :file_prefix, :file_extension, :flags, :moderator_actions] },
          :taxon_descriptions,
          { taxon_names: :place_taxon_names } ])
        @featured_taxa_obs = @featured_taxa.map do |taxon|
          taxon_obs_params = { taxon_id: taxon.id, order_by: "id", per_page: 1 }
          if @site
            taxon_obs_params[:site_id] = @site.id
          end
          Observation.page_of_results(taxon_obs_params).first
        end.compact.select{|o| o.taxon}
        Observation.preload_associations(@featured_taxa_obs, [:user, :taxon])
        
        flash[:notice] = @status unless @status.blank?
        if params[:q]
          find_taxa
          render :action => :search
        else
          @iconic_taxa = Taxon::ICONIC_TAXA
          Taxon.preload_associations(@iconic_taxa, [
            { photos: [:user, :file_prefix, :file_extension, :flags, :moderator_actions] }
          ] )
          recent_params = { d1: 1.month.ago.to_date.to_s,
            quality_grade: :research, order_by: :observed_on }
          if @site
            recent_params[:site_id] = @site.id
          end
          # group by taxon ID and get the first obs of each taxon
          @recent = Observation.page_of_results(recent_params).
            group_by(&:taxon_id).map{ |k,v| v.first }[0...5]
          Observation.preload_associations(@recent,{
            taxon: [
              { taxon_names: :place_taxon_names },
              { photos: [:user, :file_prefix, :file_extension, :flags, :moderator_actions] }
            ] } )
          @recent = @recent.sort_by(&:id).reverse
        end
      end
      format.xml  do
        render(:xml => @taxa.to_xml(:methods => [:common_name]))
      end
      format.json do
        if params[:q].blank? && params[:taxon_id].blank? && params[:place_id].blank? && params[:names].blank?
          @taxa = Taxon::ICONIC_TAXA
        end
        pagination_headers_for @taxa
        Taxon.preload_associations(@taxa, [
          { taxon_photos: { photo: :user } }, :taxon_descriptions,
          { taxon_names: :place_taxon_names }, :iconic_taxon ] )
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

  def show
    if params[:id]
      begin
        @taxon ||= Taxon.where(id: params[:id]).includes({ taxon_names: :place_taxon_names }).first
      rescue RangeError => e
        Logstasher.write_exception(e, request: request, session: session, user: current_user)
        nil
      end
    end
    
    return render_404 unless @taxon
    
    respond_to do |format|

      format.html do
        if @taxon.name == "Life" && !@taxon.parent_id
          return redirect_to( action: "index" )
        end
        
        site_place = @site && @site.place
        user_place = current_user && current_user.place
        preferred_place = user_place || site_place
        place_id = current_user.preferred_taxon_page_place_id if logged_in?
        place_id = session[:preferred_taxon_page_place_id] if place_id.blank?
        # If there's no place and there is a preferred place and this user has
        # never changed their taxon page place preference, use the preferred
        # place
        if place_id.blank? && preferred_place && !session.has_key?( :preferred_taxon_page_place_id )
          place_id = preferred_place.id
        end
        api_url = "/taxa/#{@taxon.id}?preferred_place_id=#{preferred_place.try(:id)}&place_id=#{@place.try(:id)}&locale=#{I18n.locale}"
        options = {}
        options[:authenticate] = current_user
        @node_taxon_json = INatAPIService.get_json( api_url, options )
        return render_404 unless @node_taxon_json
        @node_place_json = ( place_id.blank? || place_id == 0 ) ?
          nil : INatAPIService.get_json( "/places/#{place_id.to_i}" )
        @chosen_tab = session[:preferred_taxon_page_tab]
        @ancestors_shown = session[:preferred_taxon_page_ancestors_shown]
        render layout: "bootstrap", action: "show"
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
        Taxon.preload_associations([@taxon], [
          { taxon_photos: { photo: :user } },
          { taxon_names: :place_taxon_names }, :iconic_taxon ] )

        opts = Taxon.default_json_options
        opts[:include][:taxon_names] = {}
        opts[:include][:iconic_taxon] = {only: [:id, :name]}
        opts[:methods] += [:common_name, :image_url, :taxon_range_kml_url, :html, :default_photo]
        Taxon.preload_associations(@taxon, { taxon_photos: :photo })
        @taxon.current_user = current_user
        render :json => @taxon.to_json(opts)
      end
      format.node { render :json => jit_taxon_node(@taxon) }
    end
  end

  def browse_photos
    respond_to do |format|
      format.html do
        options = {}
        options[:api_token] = current_user.api_token if current_user
        site_place = @site && @site.place
        user_place = current_user && current_user.place
        preferred_place = user_place || site_place
        options[:authenticate] = current_user
        @node_taxon_json = INatAPIService.get_json(
          "/taxa/#{@taxon.id}?preferred_place_id=#{preferred_place.try(:id)}&place_id=#{@place.try(:id)}&locale=#{I18n.locale}",
          options
        )
        place_id = current_user.preferred_taxon_page_place_id if logged_in?
        place_id = session[:prefers_taxon_page_place_id] if place_id.blank?
        @place = Place.find_by_id( place_id )
        @ancestors_shown = session[:preferred_taxon_page_ancestors_shown]
        render layout: "bootstrap"
      end
    end
  end

  def taxonomy_details
    @rank_levels = Taxon::RANK_FOR_RANK_LEVEL.invert
    @taxon_framework = @taxon.taxon_framework
    
    if @upstream_taxon_framework = @taxon.upstream_taxon_framework
      if @upstream_taxon_framework.source_id
        @taxon_framework_relationship = TaxonFrameworkRelationship.
          includes( "taxa","external_taxa" ).
          joins( "JOIN taxa ON taxa.taxon_framework_relationship_id = taxon_framework_relationships.id" ).
          where( "taxa.id = ? AND taxon_framework_id = ?", @taxon, @upstream_taxon_framework ).first
        unless @taxon_framework
          if @taxon_framework_relationship
            @downstream_deviations_counts = @taxon_framework_relationship.internal_taxa.map{|it| {internal_taxon: it, count: TaxonFrameworkRelationship.where( "taxon_framework_id = ? AND relationship != 'match' AND relationship != 'alternate_position'", @upstream_taxon_framework.id ).internal_taxon(it).uniq.count - 1 } }
          end
          @downstream_flagged_taxa = @upstream_taxon_framework.get_flagged_taxa({taxon: @taxon})
          @downstream_flagged_taxa_count = @upstream_taxon_framework.get_flagged_taxa_count({taxon: @taxon})
        end
      end
    end
    
    if @taxon_framework
      if @taxon_framework.covers?
        @taxon_curators = @taxon_framework.taxon_curators
        @overlapping_downstream_taxon_frameworks_count = @taxon_framework.get_downstream_taxon_frameworks_count
        @overlapping_downstream_taxon_frameworks = @taxon_framework.get_downstream_taxon_frameworks
        @flagged_taxa = @taxon_framework.get_flagged_taxa
        @flagged_taxa_count = @taxon_framework.get_flagged_taxa_count
        if @taxon_framework.source_id
          @tfr_count = TaxonFrameworkRelationship.where( "taxon_framework_id = ?", @taxon_framework.id ).count
          @deviations_count = TaxonFrameworkRelationship.where( "taxon_framework_id = ? AND relationship != 'match' AND relationship != 'alternate_position'", @taxon_framework.id ).count
          @relationship_unknown_count = @taxon_framework.get_internal_taxa_covered_by_taxon_framework.where(taxon_framework_relationship_id: nil).count
        end
      end
    end
    
    respond_to do |format|
      format.html do
        render layout: "bootstrap"
      end
    end
  end
  
  def tip
    @observation = Observation.find_by_id(params[:observation_id]) if params[:observation_id]
    if @observation
      @places = @observation.public_system_places
    end
    render :layout => false
  end

  def new
    @taxon = Taxon.new( name: params[:name] )
    @protected_attributes_editable = true
  end

  def create
    @taxon = Taxon.new
    return unless presave
    @taxon.attributes = params[:taxon]
    @taxon.creator = current_user
    @taxon.current_user = current_user
    if @taxon.save
      flash[:notice] = t(:taxon_was_successfully_created)
      if locked_ancestor = @taxon.ancestors.is_locked.first
        flash[:notice] += " Heads up: you just added a descendant of a " + 
          "locked taxon (<a href='/taxa/#{locked_ancestor.id}'>" + 
          "#{locked_ancestor.name}</a>).  Please consider merging this " + 
          "into an existing taxon instead."
      end
      if parent = @taxon.parent
        if @taxon.is_active && !parent.is_active && ( taxon_change = parent.taxon_changes.where( "committed_on IS NULL" ).first )
          flash[:notice] += " Heads up: the parent of this active taxon is inactive " + 
            "but its the output of this <a href='/taxon_changes/#{taxon_change.id}'>" + 
            "draft taxon change</a> that we assume you'll commit shortly."
        end
      end
      redirect_to :action => 'show', :id => @taxon
    else
      @protected_attributes_editable = true
      render :action => 'new'
    end
  end

  def edit
    @observations_exist = @taxon.observations_count > 0
    @listed_taxa_exist = ListedTaxon.where( taxon_id: @taxon.id ).any?
    @identifications_exist = Identification.elastic_search(
      filters: [{ term: { "taxon.id" => @taxon.id } } ],
      size: 0
    ).total_entries > 0
    @descendants_exist = @taxon.descendants.exists?
    @taxon_range = TaxonRange.without_geom.where(taxon_id: @taxon).first
    unless @protected_attributes_editable = @taxon.protected_attributes_editable_by?( current_user )
      flash.now[:notice] ||= "This active taxon has more than #{Taxon::NUM_OBSERVATIONS_REQUIRING_CURATOR_TO_EDIT} downstream observations or is covered by a taxon framework, so some taxonomic attributes can only be editable by staff or taxon curators associated with that taxon framework."
    end
  end

  def update
    return unless presave
    if @taxon.update(params[:taxon])
      flash[:notice] = t(:taxon_was_successfully_updated)
      if locked_ancestor = @taxon.ancestors.is_locked.first
        flash[:notice] += " Heads up: you just added a descendant of a " + 
          "locked taxon (<a href='/taxa/#{locked_ancestor.id}'>" + 
          "#{locked_ancestor.name}</a>).  Please consider merging this " + 
          "into an existing taxon instead."
      end
      if @taxon.parent
        if @taxon.is_active && !@taxon.parent.is_active && (taxon_change = @taxon.parent.taxon_changes.where( "committed_on IS NULL" ).first)
          flash[:notice] += " Heads up: the parent of this active taxon is inactive " + 
            "but its the output of this <a href='/taxon_changes/#{taxon_change.id}'>" + 
            "draft taxon change</a> that we assume you'll commit shortly."
        end
      end
      redirect_to taxon_path(@taxon)
      return
    else
      render :action => 'edit'
    end
  end

  def destroy
    unless @taxon.deleteable_by?(current_user)
      flash[:error] = if @taxon.creator_id != current_user.id
        t(:you_can_only_destroy_taxa_you_created)
      else
        t(:you_cannot_delete_taxa_involved_in_taxon_changes)
      end
      redirect_back_or_default( @taxon )
      return
    end
    @taxon.destroy
    flash[:notice] = t(:taxon_deleted)
    redirect_to :action => 'index'
  end

## Custom actions ############################################################

  def clashes
    @taxon = Taxon.where( id: params[:id] ).first
    @context = params[:context]
    new_parent_id = params[:new_parent_id]
    unless new_parent_id
      flash[:error] = t( :no_new_parent_specified )
      redirect_back_or_default( @taxon )
      return
    end
    @results = @taxon.clash_analysis( new_parent_id )
    @results.each do | result |
      result[:child] = @taxon.name
      result[:old_parent] = Taxon.where( id: result[:parent_id] ).first.name
      result[:new_parent] = Taxon.where( id: new_parent_id ).first.name
    end
    respond_to do | format |
      format.html do
        render partial: "clashes.html.haml", locals: { results: @results }
      end
      format.json do
        render json: @results.to_json( methods: [:html] )
      end
    end
  end

  # /taxa/browse?q=bird
  # /taxa/browse?q=bird&places=1,2
  # TODO: /taxa/browse?q=bird&places=usa-ca-berkeley,usa-ct-clinton
  def search
    @q = params[:q].to_s.sanitize_encoding

    if params[:taxon_id]
      @taxon = Taxon.find_by_id(params[:taxon_id].to_i)
    end
    
    if params[:is_active] == "true" || params[:is_active].blank?
      @is_active = true
    elsif params[:is_active] == "false"
      @is_active = false
    else
      @is_active = params[:is_active]
    end
    
    if params[:iconic_taxa] && @iconic_taxa_ids = params[:iconic_taxa].split(',')
      @iconic_taxa_ids = @iconic_taxa_ids.map(&:to_i)
      @iconic_taxa = Taxon.find(@iconic_taxa_ids)
    end
    if params[:places] && @place_ids = params[:places].split(',')
      @place_ids = @place_ids.map(&:to_i)
      @places = Place.find(@place_ids)
    elsif @site && (@site_place = @site.place) && !params[:everywhere].yesish?
      @place_ids = [@site_place.id]
      @places = [@site_place]
    end

    page = params[:page] ? params[:page].to_i : 1
    user_per_page = params[:per_page] ? params[:per_page].to_i : 24
    user_per_page = 24 if user_per_page == 0
    user_per_page = 100 if user_per_page > 100
    per_page = page == 1 && user_per_page < 50 ? 50 : user_per_page

    filters = [ ]
    unless @q.blank?
      filters << {
        nested: {
          path: "names",
          query: {
            match: { "names.name": { query: @q, operator: "and" } }
          }
        }
      }
    end
    filters << { term: { is_active: true } } if @is_active === true
    filters << { term: { is_active: false } } if @is_active === false
    filters << { terms: { iconic_taxon_id: @iconic_taxa_ids } } if @iconic_taxa_ids
    filters << { terms: { place_ids: @place_ids } } if @place_ids
    filters << { term: { ancestor_ids: @taxon.id } } if @taxon
    search_options = { sort: { observations_count: "desc" },
      aggregate: {
        iconic_taxon_id: { "iconic_taxon_id": 12 },
        place: { "places.id": 12 }
      } }
    search_result = Taxon.elastic_search(search_options.merge(filters: filters)).
      per_page(per_page).page(page)
    # if there are no search results, and the search was performed with
    # a search ID filter, but one wasn't asked for. This will happen when
    # rendering a partner site and a search filter is
    # set automatically. Re-run the search w/o the place filter
    if search_result.total_entries == 0 && params[:places].blank? && !@place_ids.blank?
      without_place_filters = filters.select{ |f| !( f[:terms] && f[:terms][:place_ids] ) }
      search_result = Taxon.elastic_search(search_options.merge(filters: without_place_filters)).
        per_page(per_page).page(page)
    end
    @taxa = Taxon.result_to_will_paginate_collection(search_result)
    Taxon.preload_associations(@taxa, [ { taxon_names: :place_taxon_names },
      { taxon_photos: :photo }, :taxon_descriptions ] )

    @facets = { }
    if @facets[:iconic_taxon_id] = Hash[search_result.response.aggregations.iconic_taxon_id.buckets.map{ |b| [ b["key"], b["doc_count"] ]}]
      @faceted_iconic_taxa = Taxon.where(id: @facets[:iconic_taxon_id].keys).
        includes(:taxon_names, :photos)
      @faceted_iconic_taxa = Taxon.sort_by_ancestry(@faceted_iconic_taxa)
      @faceted_iconic_taxa_by_id = @faceted_iconic_taxa.index_by(&:id)
    end

    if !@places.blank? && @facets[:places] = Hash[search_result.response.aggregations.place.buckets.map{ |b| [ b["key"], b["doc_count"] ]}]
      place_ids_to_load = [@facets[:places].keys, @place_ids].flatten
      @faceted_places = Place.where("id in (?)", place_ids_to_load).order("name ASC")
      if @places.size == 1 && (place = @places.first)
        @faceted_places = @faceted_places.where(place.descendant_conditions)
      end
      @faceted_places_by_id = @faceted_places.index_by(&:id)
    end
    begin
      @taxa.blank?
    rescue
      Rails.logger.error "[ERROR] Failed taxon search: #{e}"
      @taxa = WillPaginate::Collection.new(1, 30, 0)
    end

    do_external_lookups

    @taxa.compact! unless @taxa.nil?
    unless @taxa.blank?
      # if there's an exact match among the hits, make sure it's first
      if exact_index = @taxa.index{|t| t.all_names.map(&:downcase).include?(params[:q].to_s.downcase)}
        if exact_index > 0
          @taxa.unshift @taxa.delete_at(exact_index)
        end
      end
    end

    if page == 1 && !@taxa.detect{ |t| t.name.downcase == params[:q].to_s.downcase }
      exact_taxon_scope = Taxon.where("lower(name) = ?", params[:q].to_s.downcase).
        where(is_active: true)
      if @iconic_taxa_ids
        exact_taxon_scope = exact_taxon_scope.where( iconic_taxon_id: @iconic_taxa_ids )
      end
      if exact_taxon = exact_taxon_scope.first
        @taxa.unshift exact_taxon
      end
    end

    if page == 1 && per_page != user_per_page
      old_taxa = @taxa
      @taxa = WillPaginate::Collection.create(1, user_per_page, old_taxa.total_entries) do |pager|
        pager.replace(old_taxa[0...user_per_page])
      end
    end
    
    respond_to do |format|
      format.html do
        return redirect_to params[:return_to] unless params[:return_to].blank?
        @view = BROWSE_VIEWS.include?(params[:view]) ? params[:view] : GRID_VIEW
        flash[:notice] = @status unless @status.blank?
        
        if @taxa.blank?
          @all_iconic_taxa = Taxon::ICONIC_TAXA
        end
        
        partial_path = if params[:partial] == "taxon" 
          "shared/#{params[:partial]}.html.erb"
        elsif params[:partial] 
          "taxa/#{params[:partial]}.html.erb"
        end       
        
        if partial_path && lookup_context.find_all(partial_path).any?
          render :partial => partial_path, :locals => {
            :js_link => params[:js_link]
          }
        else
          render :browse
        end
      end
      format.json do
        pagination_headers_for(@taxa)
        if params[:partial] == "elastic"
          render :json => Taxon.where(id: @taxa).load_for_index.map(&:as_indexed_json)
        else
          options = Taxon.default_json_options
          options[:include].merge!(
            :iconic_taxon => {:only => [:id, :name]},
            :taxon_names => {
              :only => [:id, :name, :lexicon, :is_valid, :position]
            }
          )
          options[:methods] += [:image_url, :default_name]
          if current_user && current_user.prefers_common_names?
            options[:methods] += [:common_name]
          end
          if params[:partial]
            partial_path = if params[:partial] == "taxon"
              "shared/#{params[:partial]}.html.erb"
            else
              "taxa/#{params[:partial]}.html.erb"
            end
          end
          @taxa.each_with_index do |t,i|
            if params[:partial]
              @taxa[i].html = render_to_string(:partial => partial_path, :locals => {:taxon => t})
              options[:methods] << :html
            end
            @taxa[i].current_user = current_user
          end
          json = @taxa.as_json( options )
          if current_user && !current_user.prefers_common_names?
            json = json.map do |jt|
              jt["taxon_names"] = jt["taxon_names"].select{|tn| tn["lexicon"] == TaxonName::LEXICONS[:SCIENTIFIC_NAMES] }
              jt
            end
          end
          render json: json
        end
      end
    end
  end
  
  def autocomplete
    @q = params[:q] || params[:term]
    @is_active = if params[:is_active] == "true" || params[:is_active].blank?
      true
    elsif params[:is_active] == "false"
      false
    else
      params[:is_active]
    end
    filters = [{
      nested: {
        path: "names",
        query: {
          match: { "names.name_autocomplete": { query: @q, operator: "and" } }
        }
      }
    }]
    filters << { term: { is_active: true } } if @is_active === true
    filters << { term: { is_active: false } } if @is_active === false
    @taxa = Taxon.elastic_paginate(
      filters: filters,
      sort: { observations_count: "desc" },
      per_page: 30,
      page: 1
    )
    # attempt to fetch the best exact match, which will go first
    exact_results = Taxon.elastic_paginate(
      filters: filters + [ {
        nested: {
          path: "names",
          query: {
            match: { "names.exact_ci" => @q }
          }
        }
      } ],
      sort: { observations_count: "desc" },
      per_page: 1,
      page: 1
    )
    if exact_results && exact_results.length > 0
      exact_result = exact_results.first
      @taxa.delete_if{ |t| t == exact_result }
      @taxa.unshift(exact_result)
    end
    Taxon.preload_associations(@taxa, [ { taxon_names: :place_taxon_names },
      :taxon_descriptions ] )
    @taxa.each do |t|
      t.html = view_context.render_in_format(:html,
        partial: "chooser",
        handlers: [:erb],
        formats: [:html],
        object: t,
        comname: t.common_name)
    end
    @taxa.uniq!
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
        render :plain => @taxa.to_json(
                 :methods => [:id, :common_name] )
      end
    end
  end
  
  #
  # List child taxa of this taxon
  #
  def children
    @taxa = @taxon.children
    if params[:is_active].noish?
      @taxa = @taxa.inactive
    elsif params[:is_active].blank? || params[:is_active].yesish?
      @taxa = @taxa.active
    end
    respond_to do |format|
      format.html { redirect_to taxon_path(@taxon) }
      format.xml do
        render :xml => @taxa.to_xml(
                :include => :taxon_names, :methods => [:common_name] )
      end
      format.json do
        options = Taxon.default_json_options
        options[:include].merge!(:taxon_names => {:only => [:id, :name, :lexicon]})
        options[:methods] += [:common_name]
        render :json => @taxa.includes([{:taxon_photos => :photo}, :taxon_names]).to_json(options)
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
    rescue Timeout::Error, JSON::ParserError => e
      Rails.logger.error "[ERROR #{Time.now}] Flickr error: #{e}"
      @photos = @taxon.photos
    end
    if params[:partial] && ALLOWED_PHOTO_PARTIALS.include?( params[:partial] )
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
      render :layout => false, :plain => content
    else
      render :layout => false, :partial => "photos", :locals => {
        :photos => @photos
      }
    end
  rescue SocketError => e
    raise unless Rails.env.development?
    Rails.logger.debug "[DEBUG] Looks like you're offline, skipping flickr"
    render :plain => "You're offline."
  end
  
  def schemes
    @scheme_taxa = TaxonSchemeTaxon.includes(:taxon_name).where(:taxon_id => @taxon.id)
    respond_to {|format| format.html}
  end
  
  def map
    @taxa = Taxon.where(id: params[:id])
    taxon_ids = if params[:taxa].is_a?(Array)
      params[:taxa]
    elsif params[:taxa].is_a?(String)
      params[:taxa].split(',')
    end
    if taxon_ids
      @taxa += Taxon.where(id: taxon_ids.map{ |t| t.to_i }).limit(20)
    end
    render_404 if @taxa.blank?
  end
  
  def range
    @taxon_range = if request.format == :geojson
      TaxonRange.where(taxon_id: @taxon.id).simplified.first
    else
      @taxon.taxon_range
    end
    unless @taxon_range
      flash[:error] = t(:taxon_doesnt_have_a_range)
      redirect_to @taxon
      return
    end
    respond_to do |format|
      format.html { redirect_to taxon_range_path( @taxon_range ) }
      format.kml { redirect_to @taxon_range.range.url }
      format.geojson { render :json => [@taxon_range].to_geojson }
    end
  end
  
  def observation_photos
    @taxon = Taxon.includes(:taxon_names).where( id: params[:id].to_i ).first
    @taxon ||= Taxon.single_taxon_for_name( params[:q] )
    licensed = %w(t any true).include?(params[:licensed].to_s)
    quality_grades = %w(research needs_id) & params[:quality_grade].to_s.split( "," )
    if per_page = params[:per_page]
      per_page = per_page.to_i > 50 ? 50 : per_page.to_i
    end
    observations = if @taxon
      obs = Observation.of(@taxon).
        joins(:photos).
        where("photos.id IS NOT NULL AND photos.user_id IS NOT NULL AND photos.license IS NOT NULL").
        paginate_with_count_over(:page => params[:page], :per_page => per_page)
      if licensed
        obs = obs.where("photos.license IS NOT NULL AND photos.license > ? OR photos.user_id = ?", Photo::COPYRIGHT, current_user)
      end
      unless quality_grades.blank?
        obs = obs.where( "quality_grade IN (?)", quality_grades )
      end
      obs.to_a
    elsif params[:q].to_i > 0
      # Look up photos associated with a specific observation
      obs = Observation.where( id: params[:q] )
      unless quality_grades.blank?
        obs = obs.where( "quality_grade IN (?)", quality_grades )
      end
      obs
    else
      filters = [ { exists: { field: "photos_count" } } ]
      unless params[:q].blank?
        searched_taxa = Observation.matching_taxon_ids( params[:q] )
        taxon_search_filter = !searched_taxa.empty? && { terms: { "taxon.id" => searched_taxa } }
        match_filter = {
          multi_match: {
            query: params[:q],
            operator: "and",
            fields: [ :description, "user.login", "field_values.value" ]
          }
        }
        if match_filter && taxon_search_filter
          filters << {
            bool: {
              should: [
                match_filter,
                taxon_search_filter
              ]
            }
          }
        else
          filters << match_filter
        end
      end
      unless quality_grades.blank?
        filters << {
          terms: {
            quality_grade: quality_grades
          }
        }
      end
      Observation.elastic_paginate(
        filters: filters,
        per_page: per_page,
        page: params[:page])
    end
    Observation.preload_associations(observations, { photos: :user })
    @photos = observations.compact.map(&:photos).flatten.reject{|p| p.user_id.blank?}
    @photos = @photos.reject{|p| p.license.to_i <= Photo::COPYRIGHT} if licensed
    partial = params[:partial].to_s
    partial = 'photo_list_form' unless %w(photo_list_form bootstrap_photo_list_form).include?(partial)    
    respond_to do |format|
      format.html do
        render partial: "photos/#{partial}", locals: {
          photos: @photos, 
          index: params[:index],
          local_photos: false }
      end
      format.json { render json: @photos }
    end
  end

  def map_layers
    render json: {
      id: @taxon.id,
      ranges: @taxon.taxon_range.present?,
      gbif_id: @taxon.get_gbif_id,
      listed_places: @taxon.listed_taxa.joins(place: :place_geometry).exists?
    }
  end

  def taxobox
    respond_to do |format|
      format.html { render partial: "wikipedia_taxobox", object: @taxon }
    end
  end

  def update_photos
    if @taxon.photos_locked? && !current_user.is_admin?
      respond_to do |format|
        format.json do
          render status: :forbidden, json: {
            error: t(:you_dont_have_permission_to_edit_those_photos)
          }
        end
        format.any do
          flash[:error] = t(:you_dont_have_permission_to_edit_those_photos)
          redirect_back_or_default( taxon_path( @taxon ) )
        end
      end
      return
    end
    photos = retrieve_photos
    errors = photos.map do |p|
      p.valid? ? nil : p.errors.full_messages
    end.flatten.compact
    @taxon.photos = photos
    if @taxon.save
      @taxon.reload
      @taxon.elastic_index!
    else
      errors << "Failed to save taxon: #{@taxon.errors.full_messages.to_sentence}"
    end
    unless photos.count == 0
      Taxon.delay( priority: INTEGRITY_PRIORITY ).update_ancestor_photos( @taxon.id, photos.first.id )
    end
    respond_to do |format|
      format.json { render json: @taxon.to_json }
      format.any do
        if errors.blank?
          flash[:notice] = t(:taxon_photos_updated)
        else
          flash[:error] = t(:some_of_those_photos_couldnt_be_saved, :error => errors.to_sentence.downcase)
        end
        redirect_to taxon_path( @taxon )
      end
    end
  rescue Errno::ETIMEDOUT
    respond_to do |format|
      format.json { render json: { error: t(:request_timed_out) }, status: :request_timeout }
      format.any do
        flash[:error] = t(:request_timed_out)
        redirect_back_or_default( taxon_path( @taxon ) )
      end
    end
  end

  #
  # Basically the same as update photos except it just takes a JSON array of
  # photo-like objects congtaining the keys id, type, and native_photo_id, and
  # sets them as the photos, respecting their position.
  #
  def set_photos
    if @taxon.photos_locked? && !current_user.is_admin?
      respond_to do |format|
        format.json do
          render status: :forbidden, json: {
            error: t(:you_dont_have_permission_to_edit_those_photos)
          }
        end
      end
      return
    end
    photos = ( params[:photos] || [] ).map { |photo|
      subclass = LocalPhoto
      if photo[:type]
        subclass = Object.const_get( photo[:type].camelize )
      end
      record = Photo.find_by_id( photo[:id] )
      # attempt to lookup photo with native_photo_id
      if photo[:native_photo_id]
        # look within the custom subclass
        record ||= Photo.where(
          native_photo_id: photo[:native_photo_id],
          type: photo[:type],
          subtype: nil
        ).first
        unless subclass == LocalPhoto
          # look at LocalPhotos whose subtype is the custom subclass
          record ||= Photo.where(
            native_photo_id: photo[:native_photo_id],
            type: "LocalPhoto",
            subtype: subclass.name
          ).first
        end
      end
      unless record
        if api_response = subclass.get_api_response( photo[:native_photo_id] )
          record = subclass.new_from_api_response( api_response )
        end
      end
      unless record
        Rails.logger.debug "[DEBUG] failed to find record for #{photo}"
      end
      unless record.is_a?( LocalPhoto )
        # turn all remote photos into LocalPhotos
        record = Photo.local_photo_from_remote_photo( record )
      end
      record
    }.compact
    @taxon.taxon_photos = photos.map do |photo|
      taxon_photo = @taxon.taxon_photos.detect{ |tp| tp.photo_id == photo.id }
      taxon_photo ||= TaxonPhoto.new( taxon: @taxon, photo: photo )
      taxon_photo.position = photos.index( photo )
      taxon_photo.skip_taxon_indexing = true
      taxon_photo
    end
    # no need to index the taxon's observations if only photos are being changed
    @taxon.skip_observation_indexing = true
    if @taxon.save
      @taxon.reload
      @taxon.elastic_index!
    else
      Rails.logger.debug "[DEBUG] error: #{@taxon.errors.full_messages.to_sentence}"
      respond_to do |format|
        format.json do
          render status: :unprocessable_entity, json: {
            error: "Failed to save taxon: #{@taxon.errors.full_messages.to_sentence}"
          }
        end
      end
      return
    end
    unless photos.count == 0
      Taxon.delay( priority: INTEGRITY_PRIORITY ).update_ancestor_photos( @taxon.id, photos.first.id )
    end
    respond_to do |format|
      format.json { render json: @taxon }
    end
  rescue Errno::ETIMEDOUT
    respond_to do |format|
      format.json { render json: { error: t(:request_timed_out) }, status: :request_timeout }
      format.any do
        flash[:error] = t(:request_timed_out)
        redirect_back_or_default( taxon_path( @taxon ) )
      end
    end
  end

  def describe
    @describers = if @site.taxon_describers
      @site.taxon_describers.map{|d| TaxonDescribers.get_describer(d)}.compact
    elsif @taxon.iconic_taxon_name == "Amphibia" && @taxon.species_or_lower?
      [
        TaxonDescribers::Wikipedia.new( locale: I18n.locale ),
        TaxonDescribers::AmphibiaWeb,
        TaxonDescribers::Eol,
        TaxonDescribers::Inaturalist
      ]
    else
      [
        TaxonDescribers::Wikipedia.new( locale: I18n.locale ),
        TaxonDescribers::Eol,
        TaxonDescribers::Inaturalist
      ]
    end
    # Perform caching here as opposed to caches_action so we can set request headers appropriately
    key = "views/taxa/#{@taxon.id}/description?#{request.query_parameters.merge( locale: I18n.locale ).to_a.join{|k,v| "#{k}=#{v}"}}&v2"
    if cached_description = Rails.cache.read( key )
      @description = cached_description[:description]
      @describer_url = cached_description[:url]
      @describer = TaxonDescribers.get_describer( cached_description[:describer] )&.new( locale: I18n.locale )
    end
    # We only need to fetch new data for logged in users and when the cache is empty
    if logged_in? || @description.blank?
      # Fall back to English wikipedia as a last resort unless the default
      # Wikipedia describer is already in English
      if I18n.locale.to_s !~ /^en/
        @describers.insert( -2, TaxonDescribers::Wikipedia.new( locale: :en ) )
      end
      if @taxon.auto_description?
        if describer_klass = TaxonDescribers.get_describer(params[:from])
          @describer = describer_klass.new( locale: I18n.locale )
          @description = @describer.describe( @taxon )
        else
          @describers.each do |d|
            @describer = d
            @description = begin
              d.describe(@taxon)
            rescue OpenURI::HTTPError, Timeout::Error => e
              nil
            end
            break unless @description.blank?
          end
        end
        if @describers.include?(TaxonDescribers::Wikipedia) && @taxon.wikipedia_summary.blank?
          @taxon.wikipedia_summary( refresh_if_blank: true )
        end
      else
        @describer = @describers.first
      end
      if @describer
        @describer_url = @describer.page_url( @taxon )
        response.headers["X-Describer-Name"] = @describer.describer_name || @describer.name.split( "::" ).last
        response.headers["X-Describer-URL"] = @describer_url
      end
      if !@description.blank? && !logged_in?
        Rails.cache.write( key, {
          description: @description,
          describer:  @describer.describer_name || @describer.name.split( "::" ).last,
          url: @describer_url
        }, expires_in: 1.day )
      end
    # If we have cached content and a cached describer name, set the response headers
    elsif !@description.blank? && @describer
      @describer_url ||= @describer.page_url( @taxon )
      response.headers["X-Describer-Name"] = @describer.describer_name || @describer.name.split( "::" ).last
      response.headers["X-Describer-URL"] = @describer_url
    end
    respond_to do |format|
      format.html { render partial: "description" }
    end
  end

  def links
    places_exist = ListedTaxon.where( "place_id IS NOT NULL AND taxon_id = ?", @taxon ).exists?
    place = Place.find_by_id( params[:place_id] )
    taxon_links = TaxonLink.by_taxon( @taxon, reject_places: !places_exist, place: place )
    respond_to do |format|
      format.json { render json: taxon_links.map{ |tl| {
        taxon_link: tl,
        url: tl.url_for_taxon( @taxon )
      } } }
    end
  end
  
  def refresh_wikipedia_summary
    begin
      summary = @taxon.set_wikipedia_summary(force_update: true)
    rescue Timeout::Error => e
      error_text = e.message
    end
    if summary.blank?
      error_text ||= "Could't retrieve the Wikipedia " + 
        "summary for #{@taxon.name}.  Make sure there is actually a " + 
        "corresponding article on Wikipedia."
      render :status => 404, :plain => error_text
    else
      render :plain => summary
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
        format.json do
          render :json => @taxon
        end
      else
        msg = t(:there_were_some_problems_saving_those_colors, :error => @taxon.errors.full_messages.join(', '))
        format.html do
          flash[:error] = msg
          redirect_to @taxon
        end
        format.json do
          render :json => {:errors => msg}, :status => :unprocessable_entity
        end
      end
    end
  end
  
  
  def graft
    begin
      lineage = ratatosk.graft(@taxon)
    rescue Timeout::Error => e
      @error_message = e.message
    rescue RatatoskGraftError => e
      @error_message = e.message
    end
    @taxon.reload
    @error_message ||= "Graft failed. Please graft manually by editing the taxon." unless @taxon.grafted?
    
    respond_to do |format|
      format.html do
        flash[:error] = @error_message if @error_message
        redirect_to(edit_taxon_path(@taxon))
      end
      format.js do
        if @error_message
          render :status => :unprocessable_entity, :plain => @error_message
        else
          render :plain => "Taxon grafted to #{@taxon.parent.name}"
        end
      end
      format.json do
        if @error_message
          render :status => :unprocessable_entity, :json => {:error => @error_message}
        else
          render :json => {:msg => "Taxon grafted to #{@taxon.parent.name}"}
        end
      end
    end
  end

  def history
    @record = @taxon
    audit_scope = Audited::Audit.where( auditable_type: "Taxon", auditable_id: @taxon.id ).or(
      Audited::Audit.where( associated_type: "Taxon", associated_id: @taxon.id )
    )
    audited_types = %w(Taxon TaxonName PlaceTaxonName ConservationStatus)
    if audited_types.include?( params[:auditable_type] ) && ( @auditable_type = params[:auditable_type] )
      audit_scope = audit_scope.where( auditable_type: @auditable_type )
    end
    if (
        params[:auditable_id].to_i > 0 &&
        params[:auditable_id].to_s == params[:auditable_id].to_s &&
        ( @auditable_id = params[:auditable_id] )
    )
      audit_scope = audit_scope.where( auditable_id: @auditable_id )
    end
    if ( @user_id = params[:user_id] )
      audit_scope = audit_scope.where( user_id: @user_id )
    end
    if ( @audit_action = params[:audit_action] )
      audit_scope = audit_scope.where( action: @audit_action )
    end
    @audit_days = audit_scope.group( "audits.created_at::date" ).count.sort_by(&:first).reverse
    @date = params[:year] &&
      params[:month] &&
      params[:day] &&
      ( Date.parse( "#{params[:year]}-#{params[:month]}-#{params[:day]}") rescue nil )
    # At this point @audit_days is an array of arrays with the first elt of
    # each being a date sorted in descending order, so &.first&.first should
    # be the most recent date
    @date ||= @audit_days&.first&.first
    @show_all = @date && audit_scope.count < 500
    @audits = audit_scope.order( "created_at desc" )
    @audits = @audits.where( "created_at::date = ?", @date ) unless @show_all
    render layout: "bootstrap-container"
  end

  private
  def respond_to_merge_error(msg)
    respond_to do |format|
      format.html do
        flash[:error] = msg
        if @keeper && session[:return_to].to_s =~ /#{@taxon.id}/
          redirect_to @keeper
        else
          redirect_back_or_default(@keeper || @taxon)
        end
      end
      format.js do
        render :plain => msg, :status => :unprocessable_entity, :layout => false
        return
      end
      format.json { render :json => {:error => msg}, :status => unprocessable_entity}
    end
  end
  public
  
  def merge
    @keeper = Taxon.find_by_id(params[:taxon_id].to_i)
    if @keeper && !@keeper.mergeable_by?(current_user, @taxon)
      respond_to_merge_error("The merge tool can only be used for taxa you created or exact synonyms")
      return
    end

    if @keeper && @keeper.id == @taxon.id
      respond_to_merge_error "Failed to merge taxon #{@taxon.id} (#{@taxon.name}) into taxon #{@keeper.id} (#{@keeper.name}).  You can't merge a taxon with itself."
      return
    end
    
    if request.post? && @keeper
      if @taxon.id == @keeper_id
        respond_to_merge_error(t(:cant_merge_a_taxon_with_itself))
        return
      end
      
      @keeper.merge(@taxon)

      respond_to do |format|
        format.html do
          flash[:notice] = "#{@taxon.name} (#{@taxon.id}) merged into " + 
            "#{@keeper.name} (#{@keeper.id}).  #{@taxon.name} (#{@taxon.id}) " + 
            "has been deleted."
          if session[:return_to].to_s =~ /#{@taxon.id}/
            redirect_to @keeper
          else
            redirect_back_or_default(@keeper)
          end
        end
        format.json { render :json => @keeper }
      end
      return
    end
    
    respond_to do |format|
      format.html
      format.js do
        @taxon_change = TaxonChange.input_taxon(@taxon).output_taxon(@keeper).first
        @taxon_change ||= TaxonChange.input_taxon(@keeper).output_taxon(@taxon).first
        render :partial => "taxa/merge"
      end
      format.json { render :json => @keeper }
    end
  end
  
  def curation
    @flags = Flag.where(resolved: false, flaggable_type: "Taxon").
      includes(:user).
      paginate(page: params[:page]).
      order(id: :desc)
    @resolved_flags = Flag.where(resolved: true, flaggable_type: "Taxon").
      includes(:user, :resolver).order("id desc").limit(5)
    life = Taxon.find_by_name('Life')
    @ungrafted = Taxon.roots.active.where("id != ?", life).
      includes(:taxon_names).
      paginate(page: 1, per_page: 100)
  end

  def synonyms
    filters = params[:filters] || {}
    @iconic_taxon = filters[:iconic_taxon]
    @rank = filters[:rank]
    @within_iconic = filters[:within_iconic]

    @taxa = Taxon.active.page(params[:page]).
      per_page(100).
      order("rank_level").
      joins("LEFT OUTER JOIN taxa t ON t.name = taxa.name").
      where("t.id IS NOT NULL AND t.id != taxa.id AND t.is_active = ?", true)
    @taxa = @taxa.self_and_descendants_of(@iconic_taxon) unless @iconic_taxon.blank?
    @taxa = @taxa.of_rank(@rank) unless @rank.blank?
    if @within_iconic == 't'
      @taxa = @taxa.where("taxa.iconic_taxon_id = t.iconic_taxon_id OR taxa.iconic_taxon_id IS NULL OR t.iconic_taxon_id IS NULL")
    end
    @synonyms = Taxon.active.
      where("name IN (?)", @taxa.map{|t| t.name}).
      includes(:taxon_names, :taxon_schemes)
    @synonyms_by_name = @synonyms.group_by{|t| t.name}
  end
  
  def flickr_tagger    
    f = get_flickraw
    
    @taxon ||= Taxon.find_by_id(params[:id].to_i) if params[:id]
    @taxon ||= Taxon.find_by_id(params[:taxon_id].to_i) if params[:taxon_id]
    
    @flickr_photo_ids = [params[:flickr_photo_id], params[:flickr_photos]].flatten.compact
    @flickr_photos = @flickr_photo_ids.map do |flickr_photo_id|
      begin
        original = f.photos.getInfo(:photo_id => flickr_photo_id)
        flickr_photo = FlickrPhoto.new_from_api_response(original)
        if flickr_photo && @taxon.blank?
          if @taxa = flickr_photo.to_taxa
            @taxon = @taxa.sort_by{|t| t.ancestry || ''}.last
          end
        end
        flickr_photo
      rescue FlickRaw::FailedResponse => e
        flash[:notice] = t(:sorry_one_of_those_flickr_photos_either_doesnt_exist_or)
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
      flash[:notice] = t(:you_didnt_select_any_photos_to_tag)
      redirect_to :action => 'flickr_tagger' and return
    end
    
    unless logged_in? && current_user.flickr_identity
      flash[:notice] = t(:sorry_you_need_to_be_signed_in_and)
      redirect_to :action => 'flickr_tagger' and return
    end
    
    flickr = get_flickraw
    
    photos = Photo.where(subtype: 'FlickrPhoto', native_photo_id: params[:flickr_photos]).includes(:observations)
    
    params[:flickr_photos].each do |flickr_photo_id|
      tags = params[:tags]
      photo = nil
      if photo = photos.detect{|p| p.native_photo_id == flickr_photo_id && p.subtype == "FlickrPhoto" }
        tags += " " + photo.observations.map{|o| "inaturalist:observation=#{o.id}"}.join(' ')
        tags.strip!
      end
      tag_flickr_photo(flickr_photo_id, tags, :flickr => flickr)
      return redirect_to :action => "flickr_tagger" unless flash[:error].blank?
    end
    
    flash[:notice] = t(:your_photos_have_been_tagged)
    redirect_to :action => 'flickr_photos_tagged', 
      :flickr_photos => params[:flickr_photos], :tags => params[:tags]
  end
  
  def tag_flickr_photos_from_observations
    if params[:o].blank?
      flash[:error] = t(:you_didnt_select_any_observations)
      return redirect_back_or_default( flickr_tagger_path )
    end
    
    @observations = current_user.observations.where(id: params[:o].split(',')).
      includes([ :photos, { :taxon => :taxon_names } ])
    
    if @observations.blank?
      flash[:error] = t(:no_observations_matching_those_ids)
      return redirect_back_or_default( flickr_tagger_path )
    end
    
    if @observations.map(&:user_id).uniq.size > 1 || @observations.first.user_id != current_user.id
      flash[:error] = t(:you_dont_have_permission_to_edit_those_photos)
      return redirect_back_or_default( flickr_tagger_path )
    end
    
    flickr = get_flickraw

    flickr_photo_ids = []
    @observations.each do | observation |
      observation.photos.each do | photo |
        next unless photo.is_a?( FlickrPhoto ) || photo.subtype == "FlickrPhoto"
        next unless observation.taxon

        tags = observation.taxon.to_tags
        tags << "inaturalist:observation=#{observation.id}"
        tag_flickr_photo( photo.native_photo_id, tags, flickr: flickr )
        unless flash[:error].blank?
          return redirect_back_or_default( flickr_tagger_path )
        end

        flickr_photo_ids << photo.native_photo_id
      end
    end

    redirect_to :action => 'flickr_photos_tagged', :flickr_photos => flickr_photo_ids
  end
  
  def flickr_photos_tagged
    flickr = get_flickraw
    
    @tags = params[:tags]
    
    if params[:flickr_photos].blank?
      flash[:error] = t(:no_flickr_photos_tagged)
      return redirect_to :action => "flickr_tagger"
    end
    
    @flickr_photos = params[:flickr_photos].map do |flickr_photo_id|
      begin
        fp = flickr.photos.getInfo(:photo_id => flickr_photo_id)
        FlickrPhoto.new_from_flickraw(fp, :user => current_user)
      rescue FlickRaw::FailedResponse => e
        nil
      end
    end.compact

    
    @observations = current_user.observations.joins(:photos).
      where(photos: { native_photo_id: @flickr_photos.map(&:native_photo_id), subtype: FlickrPhoto.to_s })
    @observations_by_native_photo_id = {}
    @observations.each do |observation|
      observation.photos.each do |flickr_photo|
        @observations_by_native_photo_id[flickr_photo.native_photo_id] = observation
      end
    end
  end
  
  # Try to find a taxon from urls like /taxa/Animalia or /taxa/Homo_sapiens
  def try_show
    name, format = params[:q].to_s.sanitize_encoding.split('_').join(' ').split('.')
    request.format = format if request.format.blank? && !format.blank?
    # If this is not a show URL, the taxon should still be the first segment
    name = name.to_s.downcase.split( "/" ).first
    @taxon = Taxon.single_taxon_for_name(name)
    
    # Redirect to a canonical form
    if @taxon
      # If this is not a show URL, try to redirect to a canonical version of that url
      if params[:q].include?( "/" ) && request.get?
        url_pieces = params[:q].split( "/" )
        url_pieces.shift
        new_path = "/taxa/#{@taxon.to_param}/#{url_pieces.join( "/" )}"
        begin
          recognized_route = Rails.application.routes.recognize_path( new_path )
          if recognized_route && recognized_route[:action] != "try_show"
            redirect_to new_path
          else
            render_404
          end
        rescue ActionController::RoutingError
          render_404
        end
        return
      end
      canonical = @taxon.name.split.join( "_" )
      taxon_names ||= @taxon.taxon_names.limit(100)
      acceptable_names = [canonical] + taxon_names.map{|tn| tn.name.split.join('_')}
      unless acceptable_names.include?(params[:q])
        sciname_candidates = [
          params[:action].to_s.sanitize_encoding.split.join('_').downcase, 
          params[:q].to_s.sanitize_encoding.split.join('_').downcase,
          canonical.downcase
        ]
        redirect_target = if sciname_candidates.include?(@taxon.name.split.join('_').downcase)
          @taxon.name.split.join('_')
        else
          canonical
        end
        return redirect_to( taxa_try_show_path( { q: redirect_target }.merge( request.GET ) ) )
      end
    end
    
    # TODO: if multiple exact matches, render a disambig page with status 300 (Mulitple choices)
    unless @taxon
      return redirect_to :action => 'search', :q => name
    end

    params.delete(:q)
    return_here
    show
  end
  
## Protected / private actions ###############################################
  private
  
  def find_taxa
    @taxa = Taxon.order("taxa.name ASC").includes(:taxon_names, :taxon_photos, :taxon_descriptions)
    @taxa = @taxa.from_place(params[:place_id]) unless params[:place_id].blank?
    if !params[:taxon_id].blank? && (@ancestor = Taxon.find_by_id(params[:taxon_id]))
      @taxa = @taxa.self_and_descendants_of(@ancestor)
    end
    if params[:rank] == "species_or_lower"
      @taxa = @taxa.where("rank_level <= ?", Taxon::SPECIES_LEVEL)
    elsif !params[:rank].blank?
      @taxa = @taxa.of_rank(params[:rank])
    end
    
    @qparams = {}
    if !params[:q].blank?
      @qparams[:q] = params[:q]
      where =  [ "taxon_names.name LIKE ?", '%' + params[:q].split(' ').join('%') + '%' ]
      if params[:all_names] == 'true'
        @qparams[:all_names] = params[:all_names]
        where[0] += " OR taxon_names.name LIKE ?"
        where << ('%' + params[:q].split(' ').join('%') + '%')
      end
      @taxa = @taxa.joins(:taxon_names).where(where)
    elsif params[:name]
      @qparams[:name] = params[:name]
      @taxa = @taxa.where("name = ?", params[:name])
    elsif params[:names]
      names = if params[:names].is_a?(String)
        params[:names].split(',')
      else
        params[:names]
      end
      taxon_names = TaxonName.where("name IN (?)", names).limit(100)
      @taxa = @taxa.where("taxa.is_active = ? AND taxa.id IN (?)", true, taxon_names.map(&:taxon_id).uniq)
    end
    if params[:limit]
      limit = params[:limit].to_i
      limit = 30 if limit <= 0 || limit > 200
      @qparams[:limit] = limit
      @taxa = @taxa.page(1).per_page(limit)
    else
      page = params[:page].to_i
      page = 1 if page <= 0
      per_page = params[:per_page].to_i
      per_page = 30 if per_page <= 0 || per_page > 200
      @taxa = @taxa.page(page)
      @taxa = @taxa.per_page(per_page)
    end
    do_external_lookups
  end
  
  def retrieve_photos
    [retrieve_remote_photos, retrieve_local_photos].flatten.compact
  end
  
  def retrieve_remote_photos
    photo_classes = Photo.subclasses - [LocalPhoto]
    photos = []
    photo_classes.each do |photo_class|
      param = photo_class.to_s.underscore.pluralize
      next if params[param].blank?
      params[param].reject {|i| i.blank?}.uniq.each do |photo_id|
        if fp = LocalPhoto.where( subtype: photo_class.name, native_photo_id: photo_id ).first
          photos << fp 
        else
          pp = photo_class.get_api_response(photo_id) rescue nil
          photos << photo_class.new_from_api_response(pp) if pp
        end
      end
    end
    photos
  end
  
  def retrieve_local_photos
    return [] if params[:local_photos].blank?
    photos = []
    params[:local_photos].reject {|i| i.blank?}.uniq.each do |photo_id|
      if fp = LocalPhoto.find_by_native_photo_id(photo_id)
        photos << fp 
      end
    end
    photos
  end
  
  def load_taxon
    unless @taxon = Taxon.where(id: params[:id]).includes(:taxon_names).first
      render_404
      return false
    end
    @taxon.current_user = current_user
  rescue RangeError
    render_404
    return false
  end
  
  def do_external_lookups
    return if CONFIG.content_freeze_enabled
    return unless logged_in?
    return unless params[:force_external] || (params[:include_external] && @taxa.blank?)
    start = Time.now
    @external_taxa = []
    begin
      ext_names = TaxonName.find_external(params[:q], :src => params[:external_src])
    rescue Timeout::Error, NameProviderError => e
      @status = e.message
      return
    end

    ext_taxon_ids = ext_names.map(&:taxon_id).compact
    @external_taxa = Taxon.find( ext_taxon_ids ) unless ext_taxon_ids.blank?

    return if @external_taxa.blank?

    # graft in the background
    @external_taxa.each do |external_taxon|
      external_taxon.delay(:priority => USER_INTEGRITY_PRIORITY).graft_silently unless external_taxon.grafted?
      if external_taxon.created_at > start
        external_taxon.update( creator: current_user )
      end
    end

    @taxa = WillPaginate::Collection.create(1, @external_taxa.size) do |pager|
      pager.replace(@external_taxa)
      pager.total_entries = @external_taxa.size
    end
  end
  
  def tag_flickr_photo(flickr_photo_id, tags, options = {})
    flickr = options[:flickr] || get_flickraw
    # Strip and enclose multiword tags in quotes
    if tags.is_a?(Array)
      tags = tags.map do |t|
        t.strip.match(/\s+/) ? "\"#{t.strip}\"" : t.strip
      end.join(' ')
    end
    
    begin
      flickr.photos.addTags(:photo_id => flickr_photo_id, :tags => tags)
    rescue FlickRaw::FailedResponse, FlickRaw::OAuthClient::FailedResponse => e
      if e.message =~ /Insufficient permissions/ || e.message =~ /signature_invalid/
        auth_url = auth_url_for('flickr', :scope => 'write')
        flash[:error] = ("#{@site.site_name_short} can't add tags to your photos until " +
          "Flickr knows you've given us permission.").html_safe
      else
        flash[:error] = "Something went wrong trying to to post those tags: #{e.message}"
      end
    rescue Exception => e
      flash[:error] = "Something went wrong trying to to post those tags: #{e.message}"
    end
  end
  
  def presave
    Rails.cache.delete(@taxon.photos_cache_key)
    if params[:taxon_names]
      TaxonName.update(params[:taxon_names].keys, params[:taxon_names].values)
    end
    
    unless params[:taxon][:parent_id].blank?
      unless Taxon.exists?(params[:taxon][:parent_id].to_i)
        flash[:error] = "That parent taxon doesn't exist (try a different ID)"
        render :action => 'edit'
        return false
      end
    end
    
    # Set the last editor
    params[:taxon][:updater_id] = current_user.id
    
    # Anyone who's allowed to create or update should be able to skip locks
    params[:taxon][:skip_locks] = true
    
    if params[:taxon][:featured_at] && params[:taxon][:featured_at] == "1"
      params[:taxon][:featured_at] = Time.now
    else
      params[:taxon][:featured_at] = ""
    end

    # Assign the current user to any new conservation statuses
    if params[:taxon][:conservation_statuses_attributes]
      params[:taxon][:conservation_statuses_attributes].each do |position, status|
        if existing = @taxon.conservation_statuses.detect{|cs| cs.id == status["id"].to_i }
          cs_attrs = params[:taxon][:conservation_statuses_attributes][position].clone
          cs_attrs.delete(:_destroy)
          %i[geoprivacy place_id].each {|k| cs_attrs[k] = nil if cs_attrs[k].blank? }
          existing.assign_attributes( cs_attrs )
          if existing.changed?
            params[:taxon][:conservation_statuses_attributes][position][:updater_id] = current_user.id
          end
        else
          params[:taxon][:conservation_statuses_attributes][position][:user_id] = current_user.id
        end
      end
    end

    if !current_user.is_admin? && params[:taxon][:photos_locked] &&
        params[:taxon][:photos_locked] != @taxon.photos_locked
      params[:taxon].delete(:photos_locked)
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
    xml = Nokogiri::XML( Net::HTTP.get( URI( url ) ) )
    if xml.blank? || xml.at(:error)
      get_amphibiaweb(taxon_names)
    else
      xml
    end
  end
  
  def ensure_flickr_write_permission
    @provider_authorization = current_user.provider_authorizations.where(provider_name: "flickr").first
    if @provider_authorization.blank? || @provider_authorization.scope != 'write'
      session[:return_to] = request.get? ? request.fullpath : request.env['HTTP_REFERER']
      redirect_to url_for( controller: :flickr, action: :options, scope: "write" )
      return false
    end
  end

  def taxon_curator_required
    unless @taxon.editable_by?( current_user )
      flash[:notice] = t(:you_dont_have_permission_to_edit_that_taxon)
      if session[:return_to] == request.fullpath
        redirect_to root_url
      else
        redirect_back_or_default(root_url)
      end
      return false
    end
  end

end
