# frozen_string_literal: true

class PlacesController < ApplicationController
  include Shared::WikipediaModule
  include Shared::GuideModule

  before_action :authenticate_user!, except: [
    :autocomplete,
    :cached_guide,
    :children,
    :geometry,
    :guide,
    :guide_widget,
    :index,
    :search,
    :show,
    :taxa,
    :wikipedia
  ]
  before_action :return_here, only: [:show]
  before_action :load_place, only: [
    :cached_guide,
    :children,
    :destroy,
    :edit,
    :geometry,
    :guide_widget,
    :merge,
    :show,
    :taxa,
    :update,
    :widget
  ]
  before_action :limit_page_param_for_search, only: [:search]
  before_action :editor_required, only: [:edit, :update, :destroy]
  before_action :curator_required, only: [:planner, :merge]
  before_action :check_quota, only: [:create]

  QUOTA = 3

  # Place names that cause some problem when we show associated Wikipedia
  # content
  PROBLEM_WIKIPEDIA_NAMES = ["tamborine"].freeze

  caches_page :geometry
  caches_action :cached_guide,
    expires_in: 1.hour,
    cache_path: proc {| c | c.params.merge( locale: I18n.locale ) },
    if: proc {| c | c.session.blank? || c.session["warden.user.user.key"].blank? }
  cache_sweeper :place_sweeper, only: [:update, :destroy, :merge]

  before_action :allow_external_iframes, only: [:guide_widget, :cached_guide]

  requires_privilege :organizer, only: [:new, :create, :edit, :update, :destroy],
    if: proc {| _c |
      # Only check privileges if the current user didn't create the place, i.e.
      # allow people to edit places they created even if they haven't earned the
      # organizer privilege
      if @place.blank?
        true
      else
        current_user.id != @place.user_id
      end
    }
  protect_from_forgery with: :exception, unless: lambda {
    request.parameters[:action] == "autocomplete" && request.format.json?
  }

  ALLOWED_SHOW_PARTIALS = %w(autocomplete_item).freeze

  def index
    respond_to do | format |
      format.html do
        place = @site.place
        key = place ? "random_place_ids_#{place.id}" : "random_place_ids"
        place_ids = Rails.cache.fetch( key, expires_in: 15.minutes ) do
          places = if place
            place.children.select( "id" ).order( Arel.sql( "RANDOM()" ) ).limit( 50 )
          else
            Place.where( "admin_level IS NOT NULL" ).select( :id ).
              order( Arel.sql( "RANDOM()" ) ).limit( 50 )
          end
          places.map( &:id )
        end
        place_ids = place_ids.sort_by { rand }[0..4]
        @places = Place.where( "id in (?)", place_ids )
      end

      format.json do
        @ancestor = Place.find_by_id( params[:ancestor_id].to_i ) unless params[:ancestor_id].blank?
        scope = if @ancestor
          @ancestor.descendants
        else
          Place.all
        end
        if params[:q] || params[:term]
          q = ( params[:q] || params[:term] ).to_s.sanitize_encoding
          scope = scope.dbsearch( q )
        end
        if !params[:place_type].blank?
          scope = scope.place_type( params[:place_type] )
        elsif !params[:place_types].blank?
          scope = scope.place_types( params[:place_types] )
        end
        unless params[:taxon].blank?
          if !params[:place_type].blank? && params[:place_type].downcase == "continent"
            country_scope = Place.place_types( ["country"] ).listing_taxon( params[:taxon] )
            if ListedTaxon::ESTABLISHMENT_MEANS.include?( params[:establishment_means] )
              country_scope = country_scope.with_establishment_means( params[:establishment_means] )
            end
            continent_ids = country_scope.select( "ancestry" ).map( &:parent_id )
            scope = scope.where( "places.id IN (?)", continent_ids )
          else
            scope = scope.listing_taxon( params[:taxon] )
            if ListedTaxon::ESTABLISHMENT_MEANS.include?( params[:establishment_means] )
              scope = scope.with_establishment_means( params[:establishment_means] )
            end
          end
        end
        if !params[:latitude].blank? && !params[:longitude].blank?
          lat = params[:latitude].to_f
          lon = params[:longitude].to_f
          scope = scope.containing_lat_lng( lat, lon )
        end
        per_page = params[:per_page].to_i
        per_page = 200 if per_page > 200
        per_page = 30 if per_page < 1
        render json: scope.paginate( page: params[:page], per_page: per_page ).to_a
      end
    end
  end

  def search
    @q = params[:q].to_s.sanitize_encoding
    if params[:limit]
      @limit ||= params[:limit].to_i
      @limit = 100 if @limit > 100
    else
      @limit = 30
    end
    response = INatAPIService.get(
      "/search",
      q: @q,
      page: params[:page].to_i <= 0 ? 1 : params[:page].to_i,
      per_page: @limit,
      sources: "places",
      ttl: logged_in? ? "-1" : nil
    )
    places = Place.where( id: response.results.map {| r | r["record"]["id"] } ).index_by( &:id )
    @places = WillPaginate::Collection.create( response["page"] || 1, response["per_page"] || 0,
      response["total_results"] || 0 ) do | pager |
      pager.replace( response.results.map {| r | places[r["record"]["id"]] } )
    end
    Place.preload_associations( @places, :place_geometry_without_geom )
    respond_to do | format |
      format.html
    end
  end

  def show
    @place_geometry = PlaceGeometry.without_geom.where( place_id: @place ).first
    browsing_taxon_ids = Taxon::ICONIC_TAXA.map {| it | it.ancestor_ids + [it.id] }.flatten.uniq
    browsing_taxa = Taxon.joins( :taxon_names ).where( id: browsing_taxon_ids ).
      where( "taxon_names.name != 'Life'" ).includes( taxon_names: :place_taxon_names ).
      order( :ancestry, :name )
    @arranged_taxa = Taxon.arrange_nodes( browsing_taxa )
    respond_to do | format |
      format.html do
        @projects = Project.in_place( @place ).page( 1 ).order( "projects.title" ).per_page( 50 ).to_a
        @projects += Project.joins( "JOIN rules ON rules.ruler_type = 'Project' AND rules.ruler_id = projects.id" ).
          where( "rules.operand_type = 'Place' AND rules.operand_id = ?", @place.id ).
          page( 1 ).per_page( 50 ).to_a
        @projects = @projects[0..50].sort_by {| p | p.title.downcase }
        @wikipedia = WikipediaService.new
        if logged_in?
          @subscriptions = @place.update_subscriptions.where( user_id: current_user )
        end
        @show_leaderboard = @place_geometry && @place.bbox_area < 1000
      end
      format.json do
        if ( partial = params[:partial] ) && ALLOWED_SHOW_PARTIALS.include?( partial )
          @place.html = render_to_string( partial: "#{partial}.html.erb", object: @place )
        end
        render( json: @place.to_json(
          methods: [:place_type_name, :html]
        ) )
      end
    end
  end

  def geometry
    respond_to do | format |
      format.kml do
        if @place.place_geometry_without_geom
          @kml = Place.connection.execute(
            "SELECT ST_AsKML(ST_SetSRID(geom, 4326)) AS kml FROM place_geometries WHERE place_id = #{@place.id}"
          )[0]["kml"]
        end
      end
      format.geojson do
        result = Place.connection.execute(
          "SELECT ST_AsGeoJSON(ST_SetSRID(geom, 4326)) AS geojson FROM place_geometries WHERE place_id = #{@place.id}"
        )
        if result&.count&.positive?
          @geojson = result[0]["geojson"]
        end
        render json: @geojson || {}
      end
    end
  end

  def new
    @place = Place.new
    @user_quota_reached = quota_reached?
  end

  def create
    @place = Place.new( params[:place] )
    @place.user = current_user
    if params[:file]
      assign_geometry_from_file
    elsif !params[:geojson].blank?
      @geometry = geometry_from_geojson( params[:geojson] )
      @place.validate_with_geom( @geometry, max_area_km2: max_area_km2, max_observation_count: max_observation_count )
    end

    if @geometry # && @place.valid?
      @place.save_geom( @geometry, max_area_km2: max_area_km2, max_observation_count: max_observation_count )
      @place.save
      if @place.too_big_for_check_list?
        notice = t( :place_too_big_for_check_list )
        @place.check_list&.destroy
        @place.update( prefers_check_lists: false )
      end
    end

    if @place.errors.any?
      flash[:error] = t( :there_were_problems_importing_that_place_geometry,
        error: @place.errors.full_messages.join( ", " ) )
    end
    if @place.save
      notice ||= t( :place_imported )
      flash[:notice] = notice
      redirect_to @place
    else
      flash.now[:error] =
        t( :there_were_problems_importing_that_place, place_error: @place.errors.full_messages.join( ", " ) )
      render action: :new
    end
  end

  def edit
    # Only the admin should be able to edit places with admin_level
    if !@place.admin_level.blank? && !current_user.is_admin?
      flash[:error] = t( :only_staff_can_edit_standard_places )
      redirect_to place_path( @place )
      return
    end

    if max_area_km2 && @place.area_km2 > max_area_km2
      flash[:error] = t( :only_staff_can_edit_large_places )
      redirect_to place_path( @place )
      nil
    end
  end

  def update
    if @place.update( params[:place] )
      if max_area_km2 && @place.area_km2 > max_area_km2
        @place.add_custom_error( :place_geometry, :is_too_large_to_edit )
      elsif params[:file]
        assign_geometry_from_file
      end

      if @place.errors.any?
        flash[:error] = t( :there_were_problems_importing_that_place_geometry,
          error: @place.errors.full_messages.join( ", " ) )
      end

      unless @place.valid?
        render action: :edit, status: :unprocessable_entity
        return
      end

      if @place.place_geometry && !@place.place_geometry.valid?
        flash[:error] =
          "Place updated, but boundary shape was invalid: #{@place.place_geometry.errors.full_messages.to_sentence}"
        flash[:error] += " You may have to edit the KML directly to fix issues like slivers."
        render action: :edit
        return
      end

      flash[:notice] = t( :place_updated )
      redirect_to @place
    else
      render action: :edit, status: :unprocessable_entity
    end
  end

  def destroy
    errors = []
    if @place.projects.exists? ||
        ProjectObservationRule.where( ruler_type: "Project", operand: @place, operator: "observed_in_place?" ).exists?
      errors << "there are people using this place in their projects"
    end
    errors << "there are people using this place in their guides" if @place.guides.exists?
    if errors.blank?
      @place.destroy
      flash[:notice] = t( :place_deleted )
      redirect_to places_path
    else
      flash[:error] = "Couldn't delete place: #{errors.to_sentence}"
      redirect_back_or_default places_path
    end
  end

  def autocomplete
    @q = params[:q] || params[:term] || params[:item]
    @q = sanitize_query( @q.to_s.sanitize_encoding )
    if @site && params[:restrict_to_site_place] != "false"
      site_place = @site.place
    end
    params[:per_page] ||= 30
    if @q.blank?
      scope = if site_place
        Place.children_of( site_place )
      else
        Place.where( "place_type = ?", Place::CONTINENT ).order( "updated_at desc" )
      end
      scope = scope.with_geom if params[:with_geom]
      scope = scope.with_check_list if params[:with_check_list]
      @places = scope.includes( :place_geometry_without_geom ).limit( params[:per_page] ).
        sort_by {| p | p.bbox_area || 0 }.reverse
    else
      # search both the autocomplete and normal field
      # autocomplete doesn't work well with 1- or 2-letter words
      filters = [{ bool: { should: [
        { match: { display_name_autocomplete: @q } },
        { match: { display_name: { query: @q, operator: "and" } } }
      ] } }]
      inverse_filters = []
      if site_place
        filters << { term: { ancestor_place_ids: site_place.id } }
      end
      if params[:with_geom]
        filters << { exists: { field: :geometry_geojson } }
      end
      if params[:with_check_list]
        inverse_filters << { exists: { field: :without_check_list } }
      end
      @places = Place.elastic_paginate(
        filters: filters,
        inverse_filters: inverse_filters,
        sort: { bbox_area: "desc" },
        per_page: params[:per_page]
      )
      Place.preload_associations( @places, :place_geometry_without_geom )
    end

    respond_to do | format |
      format.html do
        render layout: false, partial: "autocomplete"
      end
      format.json do
        @places.each_with_index do | place, i |
          @places[i].html = view_context.render_in_format(
            :html,
            partial: "places/autocomplete_item",
            object: place
          )
        end
        render json: @places.to_json( methods: [:html, :kml_url] ),
          callback: params[:callback]
      end
    end
  end

  def merge
    @merge_target = begin
      Place.find( params[:with] )
    rescue StandardError
      nil
    end
    return unless request.post?

    keepers = params.to_hash.map do | k, v |
      k.gsub( "keep_", "" ) if k =~ /^keep_/ && v == "left"
    end.compact
    keepers = nil if keepers.blank?
    unless @merge_target
      flash[:error] = t( :you_must_select_a_place_to_merge_with )
      return
    end

    if !current_user.is_admin? && ( !@place.admin_level.nil? || !@merge_target.admin_level.nil? )
      flash[:error] = t( :you_cant_merge_standard_places )
      return
    end

    @merged = @merge_target.merge( @place, keep: keepers )
    if @merged.valid?
      flash[:notice] = t( :places_merged_successfully )
      redirect_to @merged
    else
      flash[:error] =
        t( :there_merge_problems_with_the_merge, merged_errors: @merged.errors.full_messages.join( ", " ) )
    end
  end

  def children
    per_page = params[:per_page]
    per_page = 100 if per_page && per_page > 100
    @children = @place.children.order( :name ).
      paginate( page: params[:page], per_page: per_page )

    respond_to do | format |
      format.html { render partial: "place_li", collection: @children }
      format.json { render json: @children.to_json }
    end
  end

  def taxa
    per_page = params[:per_page]
    per_page = 100 if per_page && per_page.to_i > 100
    conditions = params[:photos_only] ? "photos.id IS NOT NULL" : nil
    listed_taxa = @place.listed_taxa.paginate(
      page: params[:page],
      per_page: per_page,
      select: "MAX(listed_taxa.id) AS id, listed_taxa.taxon_id",
      joins: "LEFT OUTER JOIN taxon_photos ON taxon_photos.taxon_id = listed_taxa.taxon_id " \
        "LEFT OUTER JOIN photos ON photos.id = taxon_photos.photo_id",
      group: "listed_taxa.taxon_id",
      order: "id DESC",
      conditions: conditions
    )
    @taxa = Taxon.where( id: listed_taxa.map( &:taxon_id ) ).
      includes( :iconic_taxon, :photos, :taxon_names )

    respond_to do | format |
      format.html { redirect_to @place }
      format.json do
        @taxa.map! do | taxon |
          taxon.html = render_to_string( partial: "taxa/taxon.html.erb",
            object: taxon, locals: {
              image_options: { size: "small" },
              link_image: true,
              link_name: true,
              include_image_attribution: true
            } )
          taxon
        end
        render json: @taxa.to_json(
          include: :photos,
          methods: [:image_url, :default_name, :common_name,
                    :scientific_name, :html]
        )
      end
    end
  end

  # page cached version of guide
  def cached_guide
    params.delete_if {| k, _v | !%w(controller action id).include?( k.to_s ) }
    guide
  end

  def guide
    place_id = params[:id] || params[:place_id] || params[:place]
    @place ||= if place_id.to_i.zero?
      begin
        Place.find( place_id )
      rescue ActiveRecord::RecordNotFound
        Place.elastic_paginate( filters: [{ match: { display_name: place_id } }], per_page: 1 ).first
      end
    else
      Place.find_by_id( place_id.to_i )
    end
    return render_404 unless @place

    @place_geometry = PlaceGeometry.without_geom.where( place_id: @place ).first

    show_guide do | scope |
      scope = scope.from_place( @place )
      scope = scope.where( "listed_taxa.primary_listing = true" )
      scope = scope.where( [
                            "listed_taxa.occurrence_status_level IS NULL OR listed_taxa.occurrence_status_level IN (?)",
                            ListedTaxon::PRESENT_EQUIVALENTS
                          ] )
      if ( @introduced = @filter_params[:introduced] )
        scope = scope.where( ["listed_taxa.establishment_means IN (?)", ListedTaxon::INTRODUCED_EQUIVALENTS] )
      elsif ( @native = @filter_params[:native] )
        scope = scope.where( ["listed_taxa.establishment_means IN (?)", ListedTaxon::NATIVE_EQUIVALENTS] )
      elsif ( @establishment_means = @filter_params[:establishment_means] )
        scope = case @establishment_means
        when "native"
          scope.where( ["listed_taxa.establishment_means IN (?)", ListedTaxon::NATIVE_EQUIVALENTS] )
        when "introduced"
          scope.where( ["listed_taxa.establishment_means IN (?)", ListedTaxon::INTRODUCED_EQUIVALENTS] )
        else
          scope.where( ["listed_taxa.establishment_means = ?", @establishment_means] )
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
      @comprehensive = @place.check_lists.exists?( ["taxon_id IN (?) AND comprehensive = 't'", ancestor_ids] )
      @comprehensive_list = @place.check_lists.where( taxon_id: ancestor_ids, comprehensive: "t" ).first
    end
    @listed_taxa_count = @scope.distinct.count( "taxa.id" )
    @confirmed_listed_taxa_count = @scope.
      where( "listed_taxa.first_observation_id IS NOT NULL" ).
      distinct.count( "taxa.id" )
    @listed_taxa = @place.listed_taxa.
      where( taxon_id: @taxa, primary_listing: true ).
      includes( [:place, { first_observation: :user }] )
    @listed_taxa_by_taxon_id = @listed_taxa.index_by( &:taxon_id )

    render layout: false, partial: @partial
  end

  def widget; end

  def guide_widget
    @guide_url = place_guide_url( @place )
    show_guide_widget
    render template: "guides/guide_widget"
  end

  def planner
    respond_to do | format |
      format.html { render layout: "bootstrap" }
      format.json do
        @latitude = params[:lat].to_f
        @longitude = params[:lng].to_f
        @places = Place.joins( :place_geometry ).
          where( place_type: Place::OPEN_SPACE ).
          where( "place_geometries.id IS NOT NULL" ).
          order(
            Arel.sql(
              "ST_Distance(ST_Point(places.longitude,places.latitude), ST_Point(#{@longitude},#{@latitude}))"
            )
          ).
          page( 1 )
        @data = []
        @places.each do | p |
          @data << {
            id: p.id,
            name: p.display_name,
            latitude: p.latitude,
            longitude: p.longitude,
            observations_count: Observation.joins( :observations_places ).where( "observations_places.place_id = ?",
              p ).count,
            taxa_count: Observation.select( "DISTINCT taxon_id" ).joins( :observations_places ).where(
              "observations_places.place_id = ?", p
            ).count,
            distance: lat_lon_distance_in_meters( @latitude, @longitude, p.latitude, p.longitude ) / 1000
          }
        end
        render json: { data: @data }
      end
    end
  end

  def wikipedia
    if PROBLEM_WIKIPEDIA_NAMES.include?( params[:id].to_s.downcase )
      respond_to do | format |
        format.html { head :no_content }
      end
      return
    end

    super
  end

  private

  def load_place
    @place = begin
      Place.find( params[:id] )
    rescue StandardError
      nil
    end
    return unless @place.blank?

    if params[:id].to_i.positive? || params[:id] == "0"
      render_404
    else
      redirect_to place_search_path( q: params[:id] )
    end
  end

  def filter_wikipedia_content
    hhtml = Nokogiri::HTML( @decoded )
    hhtml.search( "table[id=toc], table.metadata" ).remove
    @decoded = hhtml.to_s
    @decoded.gsub!( /\[\d+\]/, "" )
    @decoded.gsub!( /width:\d+/, "" )
    @decoded.gsub!( /white-space:\s?nowrap/, "" )
  end

  def geometry_from_messy_kml( kml )
    geometry = GeoRuby::SimpleFeatures::MultiPolygon.new
    doc = kml =~ /<kml / ? Nokogiri::XML( kml ) : Nokogiri::XML.fragment( kml )
    doc.search( "Polygon" ).each_with_index do | hpoly, _i |
      poly = GeoRuby::SimpleFeatures::Geometry.from_kml( hpoly.to_s )

      # make absolutely sure there are no z coordinates. iNat is strictly 2D,
      # so PostGIS will raise db exception if you try to save z
      poly.rings.each_with_index do | _r, i |
        poly.rings[i].points.each_with_index do | _p, j |
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

  def geometry_from_geojson( geojson )
    geometry = GeoRuby::SimpleFeatures::MultiPolygon.new
    collection = GeoRuby::SimpleFeatures::Geometry.from_geojson( geojson )
    collection.features.each do | feature |
      geometry << feature.geometry
    end
    geometry
  end

  def geometry_from_file( file )
    kml = file.read
    geometry_from_messy_kml( kml )
  end

  def editor_required
    unless @place.editable_by?( current_user )
      flash[:error] = t( :you_dont_have_permission_to_do_that )
      redirect_back_or_default( @place )
      return false
    end
    true
  end

  def assign_geometry_from_file
    if params[:file].size > file_size_limit
      # can't really add errors to model from here, unfortunately
      @place.add_custom_error( :base, "File was too big, must be less than #{file_size_limit / 1.megabyte} MB" )
    else
      @geometry = geometry_from_file( params[:file] )
      if @geometry
        @place.latitude = @geometry.envelope.center.y
        @place.longitude = @geometry.envelope.center.x
        if @place.validate_with_geom( @geometry, max_area_km2: max_area_km2, max_observation_count: max_observation_count )
          @place.save_geom( @geometry, max_area_km2: max_area_km2, max_observation_count: max_observation_count )
        end
      else
        @place.add_custom_error( :base, "File was invalid or did not contain any polygons" )
      end
    end
  end

  def check_quota
    if quota_reached?
      flash[:error] = t( :place_create_quota_exceeded, quota: QUOTA )
      redirect_back_or_default places_path
      return false
    end
    true
  end

  def quota_reached?
    @quota_reached ||= Place.where( user: current_user ).where( "created_at > ?", 1.day.ago ).count >= QUOTA
  end

  def file_size_limit
    current_user&.is_curator? ? 5.megabytes : 1.megabyte
  end

  def max_area_km2
    return nil if current_user.is_admin?

    if CONFIG.content_freeze_enabled
      # 70,000 km2 is roughly the size of West Virginia or Croatia
      70_000.0
    else
      # 700,000 km2 is roughly the size of Texas or Somalia
      700_000.0
    end
  end

  def max_observation_count
    return nil if current_user.is_admin?

    if CONFIG.content_freeze_enabled
      10_000
    else
      200_000
    end
  end
end
