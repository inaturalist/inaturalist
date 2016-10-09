#encoding: utf-8
class TaxaController < ApplicationController
  caches_page :range, :if => Proc.new {|c| c.request.format == :geojson}
  caches_action :show, :expires_in => 1.day,
    :cache_path => Proc.new{ |c| { locale: I18n.locale, mobile: c.request.format.mobile? } },
    :if => Proc.new {|c|
      !request.format.json? && (c.session.blank? || c.session['warden.user.user.key'].blank?)
    }
  caches_action :describe, :expires_in => 1.day,
    :cache_path => Proc.new { |c| c.params.merge(locale: I18n.locale) },
    :if => Proc.new {|c|
      c.session.blank? || c.session['warden.user.user.key'].blank?
    }

  before_filter :allow_external_iframes, only: [:map]
  
  include TaxaHelper
  include Shared::WikipediaModule
  
  before_filter :return_here, :only => [:index, :show, :flickr_tagger, :curation, :synonyms]
  before_filter :authenticate_user!, :only => [:edit_photos, :update_photos, 
    :update_colors, :tag_flickr_photos, :tag_flickr_photos_from_observations,
    :flickr_photos_tagged, :add_places, :synonyms]
  before_filter :curator_required, :only => [:new, :create, :edit, :update,
    :destroy, :curation, :refresh_wikipedia_summary, :merge, :synonyms, :graft]
  before_filter :load_taxon, :only => [:edit, :update, :destroy, :photos, 
    :children, :graft, :describe, :edit_photos, :update_photos, :edit_colors,
    :update_colors, :add_places, :refresh_wikipedia_summary, :merge, 
    :range, :schemes, :tip]
  before_filter :taxon_curator_required, :only => [:edit, :update,
    :destroy, :merge, :graft]
  before_filter :limit_page_param_for_search, :only => [:index,
    :browse, :search]
  before_filter :ensure_flickr_write_permission, :only => [
    :flickr_photos_tagged, :tag_flickr_photos, 
    :tag_flickr_photos_from_observations]
  before_filter :load_form_variables, :only => [:edit, :new]
  cache_sweeper :taxon_sweeper, :only => [:update, :destroy, :update_photos]
  
  GRID_VIEW = "grid"
  LIST_VIEW = "list"
  BROWSE_VIEWS = [GRID_VIEW, LIST_VIEW]
  ALLOWED_SHOW_PARTIALS = %w(chooser)
  ALLOWED_PHOTO_PARTIALS = %w(photo)
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
    find_taxa unless request.format.blank? || request.format.html? || request.format.mobile?
    
    begin
      @taxa.try(:total_entries)
    rescue => e
      Rails.logger.error "[ERROR] Taxon index failed: #{e}"
      @taxa = WillPaginate::Collection.new(1, 30, 0)
    end
    
    respond_to do |format|
      format.html do # index.html.erb
        @site_place = @site.place if @site
        @featured_taxa = Taxon.where("taxa.featured_at IS NOT NULL"). 
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
          :iconic_taxon, :photos, :taxon_descriptions,
          { taxon_names: :place_taxon_names } ])
        featured_taxa_obs = @featured_taxa.map do |taxon|
          taxon_obs_params = { taxon_id: taxon.id, order_by: "id", per_page: 1 }
          if @site
            taxon_obs_params[:site_id] = @site.id
          end
          Observation.page_of_results(taxon_obs_params).first
        end.compact
        Observation.preload_associations(featured_taxa_obs, :user)
        @featured_taxa_obs_by_taxon_id = featured_taxa_obs.index_by(&:taxon_id)
        
        flash[:notice] = @status unless @status.blank?
        if params[:q]
          find_taxa
          render :action => :search
        else
          @iconic_taxa = Taxon::ICONIC_TAXA
          recent_params = { d1: 1.month.ago.to_date.to_s,
            quality_grade: :research, order_by: :observed_on }
          if @site
            recent_params[:site_id] = @site.id
          end
          # group by taxon ID and get the first obs of each taxon
          @recent = Observation.page_of_results(recent_params).
            group_by(&:taxon_id).map{ |k,v| v.first }[0...5]
          Observation.preload_associations(@recent,{
            taxon: [ { taxon_names: :place_taxon_names }, :photos ] } )
          @recent = @recent.sort_by(&:id).reverse
        end
      end
      format.mobile do
        if request.query_parameters.blank?
          @taxa = Taxon.iconic_taxa.page(1).per_page(50)
        else
          find_taxa
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
    if params[:entry] == 'widget'
      flash[:notice] = t(:click_add_an_observation_to_the_lower_right, :site_name_short => CONFIG.site_name_short)
    end
    if params[:id]
      begin
        @taxon ||= Taxon.where(id: params[:id]).includes(:taxon_names).first
      rescue RangeError => e
        Logstasher.write_exception(e, request: request, session: session, user: current_user)
        nil
      end
    end
    return render_404 unless @taxon
    
    respond_to do |format|
      format.html do
        if @taxon.name == 'Life' && !@taxon.parent_id
          return redirect_to(:action => 'index')
        end

        place_id = params[:place_id] if logged_in? && !params[:place_id].blank?
        place_id ||= current_user.place_id if logged_in?
        place_id ||= CONFIG.place_id
        @place = Place.find(place_id) rescue nil
        @conservation_statuses = @taxon.conservation_statuses.includes(:place).sort_by do |cs|
          cs.place.blank? ? [0] : cs.place.self_and_ancestor_ids
        end
        if @place
          @conservation_status = @conservation_statuses.detect do |cs|
            @place.id == cs.place_id && cs.iucn > Taxon::IUCN_LEAST_CONCERN
          end
          @conservation_status ||= @conservation_statuses.detect do |cs|
            @place.self_and_ancestor_ids.include?( cs.place_id ) && cs.iucn > Taxon::IUCN_LEAST_CONCERN
          end
        end
        @conservation_status ||= @conservation_statuses.detect{|cs| cs.place_id.blank? && cs.iucn > Taxon::IUCN_LEAST_CONCERN}
        
        if @place
          @listed_taxon = @taxon.listed_taxa.includes(:place).
            where(place_id: @place.id).
            where( "occurrence_status_level IS NULL OR occurrence_status_level IN (?)", ListedTaxon::PRESENT_EQUIVALENTS ).first
          @listed_taxon ||= @taxon.listed_taxa.joins(:place).includes(:place).
            where(place_id: @place.self_and_ancestor_ids).
            where( "occurrence_status_level IS NULL OR occurrence_status_level IN (?)", ListedTaxon::PRESENT_EQUIVALENTS ).
            order("admin_level DESC, (places.ancestry || '/' || places.id) DESC, establishment_means").first
        end
        
        @children = @taxon.children.where(:is_active => @taxon.is_active).
          includes({ taxon_names: :place_taxon_names }).sort_by{ |c| c.name }
        @ancestors = @taxon.ancestors.includes({ taxon_names: :place_taxon_names })
        @iconic_taxa = Taxon::ICONIC_TAXA
        
        @check_listed_taxa = ListedTaxon.page(1).
          select("
            min(listed_taxa.id) AS id,
            listed_taxa.place_id,
            listed_taxa.taxon_id,
            min(listed_taxa.list_id) AS list_id,
            min(establishment_means) AS establishment_means,
            max(occurrence_status_level) AS occurrence_status_level").
          includes(:place, :list).
          group(:place_id, :taxon_id).
          where("place_id IS NOT NULL AND taxon_id = ?", @taxon)
        @sorted_check_listed_taxa = @check_listed_taxa.sort_by{|lt| lt.place.try(:place_type) || 0}.reverse
        @places = @check_listed_taxa.map{ |lt| lt.place }.compact.uniq{ |p| p.id }
        @countries = @taxon.places.where(["place_type = ?", Place::PLACE_TYPE_CODES['Country']]).
          select("places.id, place_type, code, admin_level").uniq{ |p| p.id }
        if @countries.size == 1 && @countries.first.code == 'US'
          @us_states = @taxon.places.
            where("admin_level = ? AND parent_id = ?", Place::STATE_LEVEL, @countries.first.id).
            select("places.id, place_type, code, admin_level").uniq{ |p| p.id }
        end

        @taxon_links = TaxonLink.by_taxon(@taxon, :reject_places => @places.blank?)
        @observations = Observation.page_of_results(
          taxon_id: @taxon.id, per_page: 12, order_by: "id", order: "desc")
        @photos = Rails.cache.fetch(@taxon.photos_cache_key) do
          @taxon.photos_with_backfill(:skip_external => true, :limit => 24)
        end
        
        if logged_in?
          @listed_taxa = ListedTaxon.joins(:list).
            where(taxon_id: @taxon, lists: { user_id: current_user })
          @listed_taxa_by_list_id = @listed_taxa.index_by{|lt| lt.list_id}
          @current_user_lists = current_user.lists.includes(:rules).
            where("(type IN ('LifeList', 'List') OR type IS NULL)").
            order("lower( lists.title )").
            limit(200).to_a
          if life_list_index = @current_user_lists.index{|l| l.id == current_user.life_list_id}
            @current_user_lists.insert(0, @current_user_lists.delete_at( life_list_index ) )
          end
          @lists_rejecting_taxon = @current_user_lists.select do |list|
            if list.is_a?(LifeList) && (rule = list.rules.detect{|rule| rule.operator == "in_taxon?"})
              !rule.validates?(@taxon)
            else
              false
            end
          end
        end
        
        # @taxon_ranges = @taxon.taxon_ranges.without_geom.includes(:source).limit(10).select(&:kml_url)
        # @taxon_range = if CONFIG.taxon_range_source_id
        #   @taxon_ranges.detect{|tr| tr.source_id == CONFIG.taxon_range_source_id}
        # end
        # @taxon_range ||= @taxon_ranges.detect{|tr| !tr.range.blank?}
        @taxon_ranges = @taxon.taxon_ranges_with_kml
        @taxon_range = @taxon_ranges[0]
        @additional_ranges = @taxon_ranges[1..-1]
        @taxon_gbif = "#{@taxon.name.gsub(' ','+')}*"
        @colors = @taxon.colors if @taxon.species_or_lower?
        
        unless @taxon.is_active?
          @taxon_change = TaxonChange.taxon(@taxon).last
        end
        
        render :action => 'show'
      end
      
      format.mobile do
        if @taxon.species_or_lower? && @taxon.species
          @siblings = @taxon.species.siblings.includes(:photos, :taxon_names).limit(100).sort_by{|t| t.name}
          @siblings.delete_if{|s| s.id == @taxon.id}
        else
          @children = @taxon.children.includes(:photos, :taxon_names).limit(100).sort_by{|t| t.name}
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

        opts = Taxon.default_json_options
        opts[:include][:taxon_names] = {}
        opts[:include][:iconic_taxon] = {only: [:id, :name]}
        opts[:methods] += [:common_name, :image_url, :taxon_range_kml_url, :html, :default_photo]
        Taxon.preload_associations(@taxon, { taxon_photos: :photo })
        render :json => @taxon.to_json(opts)
      end
      format.node { render :json => jit_taxon_node(@taxon) }
    end
  end

  def tip
    @observation = Observation.find_by_id(params[:observation_id]) if params[:observation_id]
    if @observation
      @places = @observation.system_places
    end
    render :layout => false
  end

  def new
    @taxon = Taxon.new(:name => params[:name])
  end

  def create
    @taxon = Taxon.new
    return unless presave
    @taxon.attributes = params[:taxon]
    @taxon.creator = current_user
    if @taxon.save
      flash[:notice] = t(:taxon_was_successfully_created)
      if locked_ancestor = @taxon.ancestors.is_locked.first
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
    # TODO: these .firsts will need to be updated
    @observations_exist = Observation.where(taxon_id: @taxon).exists? ||
      Observation.joins(:taxon).where(@taxon.descendant_conditions).exists?
    @listed_taxa_exist = ListedTaxon.where(taxon_id: @taxon).exists? ||
      ListedTaxon.joins(:taxon).where(@taxon.descendant_conditions).exists?
    @identifications_exist = Identification.where(taxon_id: @taxon).exists? ||
      Identification.joins(:taxon).where(@taxon.descendant_conditions).exists?
    @descendants_exist = @taxon.descendants.exists?
    @taxon_range = TaxonRange.without_geom.where(taxon_id: @taxon).first
  end

  def update
    return unless presave
    if @taxon.update_attributes(params[:taxon])
      flash[:notice] = t(:taxon_was_successfully_updated)
      if locked_ancestor = @taxon.ancestors.is_locked.first
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
    unless @taxon.deleteable_by?(current_user)
      flash[:error] = t(:you_can_only_destroy_taxa_you_created)
      redirect_back_or_default(@taxon)
      return
    end
    @taxon.destroy
    flash[:notice] = t(:taxon_deleted)
    redirect_to :action => 'index'
  end
  

## Custom actions ############################################################
  
  # /taxa/browse?q=bird
  # /taxa/browse?q=bird&places=1,2&colors=4,5
  # TODO: /taxa/browse?q=bird&places=usa-ca-berkeley,usa-ct-clinton&colors=blue,black
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
    if params[:colors] && @color_ids = params[:colors].split(',')
      @color_ids = @color_ids.map(&:to_i)
      @colors = Color.find(@color_ids)
    end

    page = params[:page] ? params[:page].to_i : 1
    user_per_page = params[:per_page] ? params[:per_page].to_i : 24
    user_per_page = 24 if user_per_page == 0
    user_per_page = 100 if user_per_page > 100
    per_page = page == 1 && user_per_page < 50 ? 50 : user_per_page

    search_wheres = { }
    unless @q.blank?
      search_wheres[:match] = { "names.name": { query: @q, operator: "and" } }
    end
    search_wheres[:is_active] = true if @is_active === true
    search_wheres[:is_active] = false if @is_active === false
    search_wheres[:iconic_taxon_id] =  @iconic_taxa_ids if @iconic_taxa_ids
    search_wheres["colors.id"] =  @color_ids if @color_ids
    search_wheres["place_ids"] =  @place_ids if @place_ids
    search_wheres["ancestor_ids"] =  @taxon.id if @taxon
    search_options = { sort: { observations_count: "desc" },
      aggregate: {
        color: { "colors.id": 12 },
        iconic_taxon_id: { "iconic_taxon_id": 12 },
        place: { "places.id": 12 }
      } }
    search_result = Taxon.elastic_search(search_options.merge(where: search_wheres)).
      per_page(per_page).page(page)
    # if there are no search results, and the search was performed with
    # a search ID filter, but one wasn't asked for. This will happen when
    # CONFIG.site_only_observations is true and a search filter is
    # set automatically. Re-run the search w/o the place filter
    if search_result.total_entries == 0 && params[:places].blank? && !search_wheres["place_ids"].blank?
      search_wheres.delete("place_ids")
      search_result = Taxon.elastic_search(search_options.merge(where: search_wheres)).
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

    if @facets[:colors] = Hash[search_result.response.aggregations.color.buckets.map{ |b| [ b["key"], b["doc_count"] ]}]
      @faceted_colors = Color.where(id: @facets[:colors].keys)
      @faceted_colors_by_id = @faceted_colors.index_by(&:id)
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

    if page == 1 &&
        !@taxa.detect{|t| t.name.downcase == params[:q].to_s.downcase} && 
        (exact_taxon =
          Taxon.where("lower(name) = ?", params[:q].to_s.downcase).
            where(is_active: true).first)
      @taxa.unshift exact_taxon
    end

    if page == 1 && per_page != user_per_page
      old_taxa = @taxa
      @taxa = WillPaginate::Collection.create(1, user_per_page, old_taxa.total_entries) do |pager|
        pager.replace(old_taxa[0...user_per_page])
      end
    end
    
    respond_to do |format|
      format.html do
        @view = BROWSE_VIEWS.include?(params[:view]) ? params[:view] : GRID_VIEW
        flash[:notice] = @status unless @status.blank?
        
        if @taxa.blank?
          @all_iconic_taxa = Taxon::ICONIC_TAXA
          @all_colors = Color.all
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
          options[:methods] += [:common_name, :image_url, :default_name]
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
          render :json => @taxa.to_json(options)
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
    search_wheres = { match: { "names.name_autocomplete": { query: @q, operator: "and" } } }
    search_wheres[:is_active] = true if @is_active === true
    search_wheres[:is_active] = false if @is_active === false
    @taxa = Taxon.elastic_paginate(
      where: search_wheres,
      sort: { observations_count: "desc" },
      per_page: 30,
      page: 1
    )
    # attempt to fetch the best exact match, which will go first
    exact_results = Taxon.elastic_paginate(
      where: search_wheres.merge(match: { "names.exact" => @q }),
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
      t.html = view_context.render_in_format(:html, :partial => "chooser.html.erb",
        :object => t, :comname => t.common_name)
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
        render :text => @taxa.to_json(
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
      @taxon.taxon_ranges.simplified.first
    else
      @taxon.taxon_ranges.first
    end
    unless @taxon_range
      flash[:error] = t(:taxon_doesnt_have_a_range)
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
    @taxon = Taxon.includes(:taxon_names).where(id: params[:id].to_i).first
    licensed = %w(t any true).include?(params[:licensed].to_s)
    if per_page = params[:per_page]
      per_page = per_page.to_i > 50 ? 50 : per_page.to_i
    end
    observations = if @taxon && params[:q].blank?
      obs = Observation.of(@taxon).
        joins(:photos).
        where("photos.id IS NOT NULL AND photos.user_id IS NOT NULL AND photos.license IS NOT NULL").
        paginate_with_count_over(:page => params[:page], :per_page => per_page)
      if licensed
        obs = obs.where("photos.license IS NOT NULL AND photos.license > ? OR photos.user_id = ?", Photo::COPYRIGHT, current_user)
      end
      obs.to_a
    else
      search_wheres = params[:q].blank? ? nil : {
        multi_match: {
          query: params[:q],
          operator: "and",
          fields: [ :description, "taxon.names.name", "user.login", "field_values.value" ]
        }
      }
      Observation.elastic_paginate(
        where: search_wheres,
        filters: [ { exists: { field: "photos" } } ],
        per_page: per_page,
        page: params[:page])
    end
    Observation.preload_associations(observations, :photos)
    @photos = observations.compact.map(&:photos).flatten.reject{|p| p.user_id.blank?}
    @photos = @photos.reject{|p| p.license.to_i <= Photo::COPYRIGHT} if licensed
    partial = params[:partial].to_s
    partial = 'photo_list_form' unless %w(photo_list_form bootstrap_photo_list_form).include?(partial)    
    render :partial => "photos/#{partial}", :locals => {
      :photos => @photos, 
      :index => params[:index],
      :local_photos => false }
  end
  
  def edit_photos
    @photos = @taxon.taxon_photos.sort_by{|tp| tp.id}.map{|tp| tp.photo}
    render :layout => false
  end
  
  def add_places
    unless params[:tab].blank?
      @places = case params[:tab]
      when 'countries'
        @countries = Place.where(place_type: Place::PLACE_TYPE_CODES["Country"]).order(:name)
      when 'us_states'
        if @us = Place.find_by_name("United States")
          @us.children.order(:name)
        else
          []
        end
      else
        []
      end
      
      @listed_taxa = @taxon.listed_taxa.where(place_id: @places).
        select("DISTINCT ON (place_id) listed_taxa.*")
      @listed_taxa_by_place_id = @listed_taxa.index_by(&:place_id)
      
      render :partial => 'taxa/add_to_place_link', :collection => @places, :locals => {
        :skip_map => true
      }
      return
    end
    
    if request.post?
      if params[:paste_places]
        add_places_from_paste
      else
        add_places_from_search
      end
      respond_to do |format|
        format.json do
          @places.each_with_index do |place, i|
            @places[i].html = view_context.render_in_format(:html, :partial => 'add_to_place_link', :object => place)
          end
          render :json => @places.to_json(:methods => [:html])
        end
      end
      return
    end
    render :layout => false
  end
  
  private
  def add_places_from_paste
    place_names = params[:paste_places].split(",").map{|p| p.strip.downcase}.reject(&:blank?)
    @places = Place.where( admin_level: Place::COUNTRY_LEVEL ).where( "lower(name) IN (?)", place_names )
    @listed_taxa = @places.map do |place| 
      place.check_list.try(:add_taxon, @taxon, :user_id => current_user.id)
    end.select{|p| p.valid?}
    @listed_taxa_by_place_id = @listed_taxa.index_by{|lt| lt.place_id}
  end
  
  def add_places_from_search
    search_for_places
    @listed_taxa = @taxon.listed_taxa.where(place_id: @places).
      select("DISTINCT ON (place_id) listed_taxa.*")
    @listed_taxa_by_place_id = @listed_taxa.index_by(&:place_id)
  end
  public
  
  def find_places
    @limit = 5
    @js_link = params[:js_link]
    @partial = params[:partial]
    search_for_places
    render :layout => false
  end
  
  def update_photos
    photos = retrieve_photos
    errors = photos.map do |p|
      p.valid? ? nil : p.errors.full_messages
    end.flatten.compact
    @taxon.photos = photos
    unless @taxon.save
      errors << "Failed to save taxon: #{@taxon.errors.full_messages.to_sentence}"
    end
    unless photos.count == 0
      Taxon.delay(:priority => INTEGRITY_PRIORITY).update_ancestor_photos(@taxon.id, photos.first.id)
    end
    if errors.blank?
      flash[:notice] = t(:taxon_photos_updated)
    else
      flash[:error] = t(:some_of_those_photos_couldnt_be_saved, :error => errors.to_sentence.downcase)
    end
    redirect_to taxon_path(@taxon)
  rescue Errno::ETIMEDOUT
    flash[:error] = t(:request_timed_out)
    redirect_back_or_default(taxon_path(@taxon))
  rescue Koala::Facebook::APIError => e
    raise e unless e.message =~ /OAuthException/
    flash[:error] = t(:facebook_needs_the_owner_of_that_photo_to, :site_name_short => CONFIG.site_name_short)
    redirect_back_or_default(taxon_path(@taxon))
  end
  
  def describe
    @describers = if CONFIG.taxon_describers
      CONFIG.taxon_describers.map{|d| TaxonDescribers.get_describer(d)}.compact
    elsif @taxon.iconic_taxon_name == "Amphibia" && @taxon.species_or_lower?
      [TaxonDescribers::Wikipedia, TaxonDescribers::AmphibiaWeb, TaxonDescribers::Eol]
    else
      [TaxonDescribers::Wikipedia, TaxonDescribers::Eol]
    end
    if @describer = TaxonDescribers.get_describer(params[:from])
      @description = @describer.describe(@taxon)
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
      @taxon.wikipedia_summary(:refresh_if_blank => true)
    end
    @describer_url = @describer.page_url(@taxon)
    respond_to do |format|
      format.html { render :partial => "description" }
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
      render :status => 404, :text => error_text
    else
      render :text => summary
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
          render :status => :unprocessable_entity, :text => @error_message
        else
          render :text => "Taxon grafted to #{@taxon.parent.name}"
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
        render :text => msg, :status => :unprocessable_entity, :layout => false
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
      if photo = photos.detect{|p| p.native_photo_id == flickr_photo_id}
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
      return redirect_to :back
    end
    
    @observations = current_user.observations.where(id: params[:o].split(',')).
      includes([ :photos, { :taxon => :taxon_names } ])
    
    if @observations.blank?
      flash[:error] = t(:no_observations_matching_those_ids)
      return redirect_to :back
    end
    
    if @observations.map(&:user_id).uniq.size > 1 || @observations.first.user_id != current_user.id
      flash[:error] = t(:you_dont_have_permission_to_edit_those_photos)
      return redirect_to :back
    end
    
    flickr = get_flickraw
    
    flickr_photo_ids = []
    @observations.each do |observation|
      observation.photos.each do |photo|
        next unless photo.is_a?(FlickrPhoto)
        next unless observation.taxon
        tags = observation.taxon.to_tags
        tags << "inaturalist:observation=#{observation.id}"
        tag_flickr_photo(photo.native_photo_id, tags, :flickr => flickr)
        unless flash[:error].blank?
          return redirect_to :back
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
      where(photos: { native_photo_id: @flickr_photos.map(&:native_photo_id), type: FlickrPhoto.to_s })
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
    name = name.to_s.downcase
    @taxon = Taxon.single_taxon_for_name(name)
    
    # Redirect to a canonical form
    if @taxon
      canonical = (@taxon.unique_name || @taxon.name).split.join('_')
      taxon_names ||= @taxon.taxon_names.limit(100)
      acceptable_names = [@taxon.unique_name, @taxon.name].compact.map{|n| n.split.join('_')} + 
        taxon_names.map{|tn| tn.name.split.join('_')}
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
        return redirect_to :action => redirect_target
      end
    end
    
    # TODO: if multiple exact matches, render a disambig page with status 300 (Mulitple choices)
    unless @taxon
      return redirect_to :action => 'search', :q => name
    else
      params.delete(:q)
      return_here
      show
    end
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
      @taxa = @taxa.where(where).includes(:taxon_names)
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
        if fp = photo_class.find_by_native_photo_id(photo_id)
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
      return
    end
  end
  
  def do_external_lookups
    return unless logged_in?
    return unless params[:force_external] || (params[:include_external] && @taxa.blank?)
    @external_taxa = []
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
      external_taxon.delay(:priority => USER_INTEGRITY_PRIORITY).graft_silently unless external_taxon.grafted?
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
        flash[:error] = ("#{CONFIG.site_name_short} can't add tags to your photos until " + 
          "Flickr knows you've given us permission.  " + 
          "<a href=\"#{auth_url}\">Click here to authorize #{CONFIG.site_name_short} to add tags</a>.").html_safe
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
    @provider_authorization = current_user.provider_authorizations.where(provider_name: "flickr").first
    if @provider_authorization.blank? || @provider_authorization.scope != 'write'
      session[:return_to] = request.get? ? request.fullpath : request.env['HTTP_REFERER']
      redirect_to auth_url_for('flickr', :scope => 'write')
      return false
    end
  end
  
  def load_form_variables
    @conservation_status_authorities = ConservationStatus.
      select('DISTINCT authority').where("authority IS NOT NULL").
      map(&:authority).compact.reject(&:blank?).map(&:strip).sort
  end

  def taxon_curator_required
    unless @taxon.editable_by?( current_user )
      flash[:notice] = t(:only_administrators_may_access_that_page)
      if session[:return_to] == request.fullpath
        redirect_to root_url
      else
        redirect_back_or_default(root_url)
      end
      return false
    end
  end
end
