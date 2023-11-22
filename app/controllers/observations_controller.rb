#encoding: utf-8
class ObservationsController < ApplicationController
  before_action :decide_if_skipping_preloading, only: [ :index, :show, :taxon_summary, :review ]
  before_action :allow_external_iframes, only: [:stats, :user_stats, :taxa, :map]
  before_action :allow_cors, only: [:index], 'if': -> { Rails.env.development? }

  WIDGET_CACHE_EXPIRATION = 15.minutes
  cache_sweeper :observation_sweeper, :only => [:create, :update, :destroy]

  rescue_from ::AbstractController::ActionNotFound  do
    unless @selected_user = User.find_by_login(params[:action])
      return render_404
    end
    by_login
  end

  ## AUTHENTICATION
  before_action :doorkeeper_authorize!,
    only: [ :create, :update, :destroy, :viewed_updates, :update_fields, :review ],
    if: -> { authenticate_with_oauth? }

  before_action :authenticate_user!,
                unless: -> { authenticated_with_oauth? },
                :except => [:explore,
                            :index,
                            :of,
                            :show,
                            :by_login,
                            :nearby,
                            :widget,
                            :project,
                            :stats,
                            :taxa,
                            :taxon_stats,
                            :user_stats,
                            :community_taxon_summary,
                            :map,
                            :taxon_summary,
                            :observation_links,
                            :torquemap,
                            :lifelist_by_login]
  protect_from_forgery with: :exception, if: lambda {
    !request.format.widget? && request.headers["Authorization"].blank?
  }
  ## /AUTHENTICATION

  before_action :load_user_by_login, only: [:by_login, :by_login_all, :lifelist_by_login]
  after_action :return_here, only: [
    :index,
    :by_login,
    :show,
    :import,
    :export,
    :add_from_list,
    :new,
    :project
  ]
  load_only = [ :show, :edit, :edit_photos, :update_photos, :destroy,
    :fields, :viewed_updates, :community_taxon_summary, :update_fields,
    :review, :taxon_summary, :observation_links ]
  before_action :load_observation, :only => load_only
  blocks_spam :only => load_only - [ :taxon_summary, :observation_links, :review ],
    :instance => :observation
  check_spam only: [:create, :update], instance: :observation
  before_action :require_owner, :only => [:edit, :edit_photos,
    :update_photos, :destroy]
  before_action :curator_required, :only => [:curation]
  before_action :load_photo_identities, :only => [:new, :new_batch, :show,
    :new_batch_csv,:edit, :update, :edit_batch, :create, :import, 
    :import_photos, :import_sounds, :new_from_list]
  before_action :load_sound_identities, :only => [:new, :new_batch, :show,
    :new_batch_csv,:edit, :update, :edit_batch, :create, :import, 
    :import_photos, :import_sounds, :new_from_list]
  before_action :photo_identities_required, :only => [:import_photos]
  before_action :load_prefs, :only => [:index, :project, :by_login]

  prepend_around_action :enable_replica, only: [:by_login, :show, :taxon_summary]

  ORDER_BY_FIELDS = %w"created_at observed_on project species_guess votes id"
  REJECTED_FEED_PARAMS = %w"page view filters_open partial action id locale"
  REJECTED_KML_FEED_PARAMS = REJECTED_FEED_PARAMS + %w"swlat swlng nelat nelng BBOX"
  MAP_GRID_PARAMS_TO_CONSIDER = REJECTED_KML_FEED_PARAMS +
    %w( order order_by taxon_id taxon_name projects user_id place_id utf8
        d1 d2 )
  DISPLAY_ORDER_BY_FIELDS = {
    'created_at' => 'date added',
    'observations.id' => 'date added',
    'id' => 'date added',
    'observed_on' => 'date observed',
    'species_guess' => 'species name',
    'project' => "date added to project",
    'votes' => 'faves'
  }
  PARTIALS = %w(cached_component observation_component observation mini project_observation)
  EDIT_PARTIALS = %w(add_photos)
  PHOTO_SYNC_ATTRS = [:description, :species_guess, :taxon_id, :observed_on,
    :observed_on_string, :latitude, :longitude, :place_guess]

  # GET /observations
  # GET /observations.xml
  def index
    if !logged_in? && params[:page].to_i > 100
      authenticate_user!
      return false
    end
    params = request.params
    showing_partial = (params[:partial] && PARTIALS.include?(params[:partial]))
    # Humans should see this, but scrapers like social media sites and curls
    # will set Accept: */*
    human_or_scraper = request.format.html? || request.format == "*/*"
    # the new default /observations doesn't need any observations
    # looked up now as it will use Angular/Node. This is for legacy
    # API methods, and HTML/views and partials
    if human_or_scraper && !showing_partial
      @shareable_description = begin
        generate_shareable_description
      rescue StandardError => e
        Logstasher.write_exception( e, request: request, session: session, user: current_user )
        ""
      end
    else
      h = observations_index_search(params)
      params = h[:params]
      search_params = h[:search_params]
      @observations = h[:observations]
    end
    respond_to do |format|

      format.html do
        if showing_partial
          pagination_headers_for(@observations)
          return render_observations_partial(params[:partial])
        end
        # one of the few things we do in Rails. Look up the taxon_name param
        unless params[:taxon_name].blank?
          sn = params[:taxon_name].to_s.strip.gsub(/[\s_]+/, ' ').downcase
          t = Taxon.active.where( name: sn ).first
          t ||= Taxon.where( name: sn ).first
          t ||= TaxonName.joins(:taxon).where("taxa.is_active AND lower(taxon_names.name) = ?", sn).first.try(:taxon)
          t ||= TaxonName.where("lower(taxon_names.name) = ?", sn).first.try(:taxon)
          if t
            t = t.current_synonymous_taxon unless t.is_active?
            params[:taxon_id] = t.id
          end
        end
        @asynchronous_google_maps_loading = true
        render layout: "bootstrap", locals: { params: params }
      end

      format.json do
        Observation.preload_for_component(@observations, logged_in: logged_in?)
        Observation.preload_associations(@observations, :tags)
        render_observations_to_json
      end
      
      format.geojson do
        render :json => @observations.to_geojson(:except => [
          :geom, :latitude, :longitude, :map_scale, 
          :num_identification_agreements, :num_identification_disagreements, 
          :delta, :location_is_exact])
      end
      
      format.atom do
        @updated_at = Observation.last.updated_at
      end
      
      format.dwc do
        Observation.preload_for_component(@observations, logged_in: logged_in?)
        Observation.preload_associations(@observations, [ :identifications ])
      end

      format.csv do
        render_observations_to_csv
      end
      
      format.kml do
        render_observations_to_kml(
          :snippet => "#{@site.name} Feed for Everyone",
          :description => "#{@site.name} Feed for Everyone",
          :name => "#{@site.name} Feed for Everyone"
        )
      end
      
      format.widget do
        if params[:markup_only] == 'true'
          render js: render_to_string(
            partial: "widget",
            handlers: [:erb],
            formats: [:html],
            locals: {
              show_user: true,
              target: params[:target],
              default_image: params[:default_image],
              silence: params[:silence]
            }
          )
        else
          render js: render_to_string(
            partial: "widget",
            handlers: [:erb],
            formats: [:js],
            locals: {
              show_user: true
            }
          )
        end
      end
    end
  rescue Elasticsearch::Transport::Transport::Errors::InternalServerError => e
    raise e unless e.message =~ /window is too large/
    msg = "Too many results. Try using smaller searches or the id_above parameter."
    response.headers["X-Error"] = msg
    respond_to do |format|
      format.html do
        flash[:error] = msg
        redirect_to( observations_path )
      end
      format.json { render json: { error: msg } }
      format.all { @observations = [] }
    end
  end

  def taxon_summary
    Observation.preload_associations( @observation, { observations_places: :place } )
    @coordinates_viewable = @observation.coordinates_viewable_by?(current_user)
    @places = @coordinates_viewable ?
      @observation.observations_places.map(&:place) : @observation.public_places
    taxon = params[:community] ? @observation.community_taxon : @observation.taxon
    if taxon
      unless @places.blank?
        @listed_taxon = ListedTaxon.
          joins(:place).
          where([ "taxon_id = ? AND place_id IN (?) AND establishment_means IS NOT NULL",
            taxon.id, @places ]).
          order( Arel.sql( "establishment_means IN ('endemic', 'introduced') DESC, places.bbox_area ASC" ) ).
          first
        conservation_status_in_place_scope = ConservationStatus.
          where("place_id IN (?)", @places).
          where("iucn >= ?", Taxon::IUCN_NEAR_THREATENED).
          includes(:place)
        @conservation_status = conservation_status_in_place_scope.where( taxon_id: taxon ).first
        @conservation_status = conservation_status_in_place_scope.
          where( taxon_id: taxon.self_and_ancestor_ids ).
          joins(:taxon).
          order( "taxa.rank_level ASC" ).
          first
      end
      global_conservation_status_scope = ConservationStatus.
        where("place_id IS NULL").where("iucn >= ?", Taxon::IUCN_NEAR_THREATENED)
      @conservation_status ||= global_conservation_status_scope.where( taxon_id: taxon ).first
      @conservation_status ||= global_conservation_status_scope.
        where( taxon_id: taxon.self_and_ancestor_ids ).
        joins(:taxon).
        order( "taxa.rank_level ASC" ).
        first
      if @listed_taxon
        @conservation_status ||= taxon.threatened_status(place_id: @listed_taxon.place_id)
      end
      @conservation_status ||= taxon.threatened_status
    end
    render json: {
      conservation_status: @conservation_status ?
        @conservation_status.as_json( methods: [ :status_name, :iucn_status, :iucn_status_code ],
          include: { place: { only: [:id, :display_name] } } ) : nil,
      listed_taxon: @listed_taxon && ( @listed_taxon.endemic? || @listed_taxon.introduced? ) ?
        @listed_taxon.as_json(
          methods: [ :establishment_means_label, :establishment_means_description ],
          include: { place: { only: [:id, :display_name] } } ) : nil,
      wikipedia_summary: taxon ? taxon.wikipedia_summary( locale: I18n.locale ) : nil
    }
  end

  def lifelist_by_login
    return render layout: "bootstrap"
  end

  # GET /observations/1
  # GET /observations/1.xml
  def show
    unless @skipping_preloading
      @quality_metrics = @observation.quality_metrics.includes(:user)
      if logged_in?
        @previous = Observation.page_of_results({ user_id: @observation.user.id,
          per_page: 1, max_id: @observation.id - 1, order_by: "id", order: "desc" }).first
        @prev = @previous
        @next = Observation.page_of_results({ user_id: @observation.user.id,
          per_page: 1, min_id: @observation.id + 1, order_by: "id", order: "asc" }).first
        @user_quality_metrics = @observation.quality_metrics.select{|qm| qm.user_id == current_user.id}
      end
    end
    respond_to do |format|
      format.html do
        if params[:partial] == "cached_component"
          return render(partial: "cached_component",
            object: @observation, layout: false)
        end
        @coordinates_viewable = @observation.coordinates_viewable_by?( current_user )
        user_viewed_updates(delay: true) if logged_in?
        @observer_provider_authorizations = @observation.user.provider_authorizations
        @shareable_image_url = helpers.iconic_taxon_image_url( @observation.taxon, size: 200 )
        if op = @observation.observation_photos.sort_by{|op| op.position.to_i || op.id }.first
          @shareable_image_url = helpers.image_url( op.photo.best_url(:large) )
        end
        @shareable_title = if @observation.taxon
          Taxon.preload_associations( @observation.taxon, { taxon_names: :place_taxon_names } )
          render_to_string(
            partial: "taxa/taxon",
            handlers: [:erb],
            formats: [:txt],
            locals: { taxon: @observation.taxon }
          )
        else
          I18n.t( "something" )
        end
        @shareable_description = @observation.to_plain_s(
          no_place_guess: !@coordinates_viewable,
          viewer: current_user
        )
        unless @observation.description.blank?
          @shareable_description += ".\n\n#{helpers.truncate( @observation.description, length: 100 )}"
        end

        @skip_application_js = true
        @flash_js = true
        return render layout: "bootstrap"
      end
       
      format.xml { render :xml => @observation }
      
      format.json do
        taxon_options = Taxon.default_json_options
        taxon_options[:methods] += [:iconic_taxon_name, :image_url, :common_name, :default_name]
        render :json => @observation.to_json(
          :viewer => current_user,
          force_coordinate_visibility: @observation.coordinates_viewable_by?( current_user ),
          :methods => [:user_login, :iconic_taxon_name, :captive_flag],
          :include => {
            :user => User.default_json_options,
            :observation_field_values => {:include => {:observation_field => {:only => [:name]}}},
            :project_observations => {
              :include => {
                :project => {
                  :only => [:id, :title, :description],
                  :methods => [:icon_url]
                }
              }
            },
            :observation_photos => {
              :include => {
                :photo => {
                  :methods => [:license_code, :attribution, :square_url,
                    :thumb_url, :small_url, :medium_url, :large_url],
                  :except => [:file_processing, :file_file_size,
                    :file_content_type, :file_file_name, :mobile, :metadata, :user_id, 
                    :native_realname, :native_photo_id]
                }
              }
            },
            :comments => {
              :include => {
                :user => {
                  :only => [:name, :login, :id],
                  :methods => [:user_icon_url]
                }
              }
            },
            :taxon => taxon_options,
            :identifications => {
              :include => {
                :user => {
                  :only => [:name, :login, :id],
                  :methods => [:user_icon_url]
                },
                :taxon => taxon_options
              }
            },
            :faves => {
              :only => [:created_at],
              :include => {
                :user => {
                  :only => [:name, :login, :id],
                  :methods => [:user_icon_url]
                }
              }
            }
          })
      end
      
      format.atom do
        cache
      end
    end
  end

  # GET /observations/new
  # GET /observations/new.xml
  # An attempt at creating a simple new page for batch add
  def new
    @observation = Observation.new(:user => current_user)

    if params[:copy] && (copy_obs = Observation.find_by_id(params[:copy])) && copy_obs.user_id == current_user.id
      %w(observed_on_string time_zone zic_time_zone place_guess geoprivacy map_scale positional_accuracy).each do |a|
        @observation.send("#{a}=", copy_obs.send(a))
      end
      @observation.latitude = copy_obs.private_latitude || copy_obs.latitude
      @observation.longitude = copy_obs.private_longitude || copy_obs.longitude
      copy_obs.observation_photos.each do |op|
        @observation.observation_photos.build(:photo => op.photo)
      end
      copy_obs.observation_sounds.each do |os|
        @observation.observation_sounds.build( sound: os.sound )
      end
    end
    
    @taxon = Taxon.find_by_id(params[:taxon_id].to_i) unless params[:taxon_id].blank?
    unless params[:taxon_name].blank?
      @taxon ||= TaxonName.where("lower(name) = ?", params[:taxon_name].to_s.strip.gsub(/[\s_]+/, ' ').downcase).
        first.try(:taxon)
    end
    
    if !params[:project_id].blank?
      @project = if params[:project_id].to_i == 0
        Project.includes(:project_observation_fields => :observation_field).find(params[:project_id])
      else
        Project.includes(:project_observation_fields => :observation_field).find_by_id(params[:project_id].to_i)
      end
      if @project
        @place = @project.place
        @project_curators = @project.project_users.where("role IN (?)", [ProjectUser::MANAGER, ProjectUser::CURATOR])
        @tracking_code = params[:tracking_code] if @project.tracking_code_allowed?(params[:tracking_code])
        @kml_assets = @project.project_assets.select{|pa| pa.asset_file_name =~ /\.km[lz]$/}
      end
    end

    @place ||= Place.find(params[:place_id]) unless params[:place_id].blank? rescue nil

    if @place
      @place_geometry = PlaceGeometry.without_geom.where(place_id: @place).first
    end

    sync_flickr_photo if params[:flickr_photo_id] && current_user.flickr_identity
    sync_picasa_photo if params[:picasa_photo_id] && current_user.picasa_identity
    sync_local_photo if params[:local_photo_id]
      
    @welcome = params[:welcome]
    
    # this should happen AFTER photo syncing so params can override attrs 
    # from the photo
    [:latitude, :longitude, :place_guess, :location_is_exact, :map_scale,
        :positional_accuracy, :positioning_device, :positioning_method,
        :observed_on_string].each do |obs_attr|
      next if params[obs_attr].blank?
      # sync_photo indicates that the user clicked sync photo, so presumably they'd 
      # like the photo attrs to override the URL
      # invite links are the other case, in which URL params *should* override the 
      # photo attrs b/c the person who made the invite link chose a taxon or something
      if params[:sync_photo]
        @observation.send("#{obs_attr}=", params[obs_attr]) if @observation.send(obs_attr).blank?
      else
        @observation.send("#{obs_attr}=", params[obs_attr])
      end
    end
    if @taxon
      @observation.taxon = @taxon
      @observation.species_guess = if @taxon.common_name
        @taxon.common_name( user: current_user ).name
      else
        @taxon.name
      end
    elsif !params[:taxon_name].blank?
      @observation.species_guess =  params[:taxon_name]
    end
    
    @observation_fields = ObservationField.recently_used_by(current_user).limit(10)
    @observation.set_time_zone if @observation.time_zone.blank?
    respond_to do |format|
      format.html do
        @observations = [@observation]
      end
      format.json  { render :json => @observation }
    end
  end
  
  # GET /observations/1/edit
  def edit
    # Only the owner should be able to see this.  
    unless current_user.id == @observation.user_id or current_user.is_admin?
      redirect_to observation_path(@observation)
      return
    end
    
    # Make sure user is editing the REAL coordinates
    if @observation.coordinates_obscured?
      @observation.latitude = @observation.private_latitude
      @observation.longitude = @observation.private_longitude
      @observation.place_guess = @observation.private_place_guess
    end

    sync_flickr_photo if params[:flickr_photo_id]
    sync_picasa_photo if params[:picasa_photo_id]
    sync_local_photo if params[:local_photo_id]
    @observation_fields = ObservationField.recently_used_by(current_user).limit(10)

    if @observation.quality_metrics.detect{|qm| qm.user_id == @observation.user_id && qm.metric == QualityMetric::WILD && !qm.agree?}
      @observation.captive_flag = true
    end

    if params[:interpolate_coordinates].yesish?
      @observation.interpolate_coordinates
    end

    # If the value of time_zone is actually the zic or IANA time zone, make sure
    # it gets set to the Rails time zone name for editing purposes
    if ActiveSupport::TimeZone::MAPPING.invert[@observation.time_zone]
      @observation.time_zone = ActiveSupport::TimeZone::MAPPING.invert[@observation.time_zone]
    end

    respond_to do |format|
      format.html do
        if params[:partial] && EDIT_PARTIALS.include?(params[:partial])
          return render(:partial => params[:partial], :object => @observation,
            :layout => false)
        end
      end
    end
  end

  # POST /observations
  # POST /observations.xml
  def create
    # Handle the case of a single obs
    params[:observations] = [['0', params[:observation]]] if params[:observation]
    
    if params[:observations].blank? && params[:observation].blank?
      respond_to do |format|
        format.html do
          flash[:error] = t(:no_observations_submitted)
          redirect_to new_observation_path
        end
        format.json { render :status => :unprocessable_entity, :json => "No observations submitted!" }
      end
      return
    end
    
    @observations = params[:observations].to_h.map do |fieldset_index, observation|
      next if observation.blank?
      observation.delete('fieldset_index') if observation[:fieldset_index]
      unless observation.is_a?( ActionController::Parameters )
        observation = ActionController::Parameters.new( observation )
      end

      # If the client is trying to create an observation that already exists,
      # update that observation instead of returning an error. This is meant to
      # handle cases where the client submits a create request, the server
      # receives it, but the client loses its connection before receiving a
      # response. The client then thinks the request was not successful and
      # tries to submit a create request again when it has network. We are not
      # simply returning the existing state of the observation here because the
      # client might have changed its copy of the observation in the interim.
      o = unless observation[:uuid].blank?
        current_user.observations.where( uuid: observation[:uuid] ).first
      end
      # when we add UUIDs to everything and either stop using strings or
      # ensure that everything is lowercase, we can stop doing this
      if o.blank? && !observation[:uuid].blank?
        o = current_user.observations.where( uuid: observation[:uuid].downcase ).first
      end

      o ||= Observation.new
      o.assign_attributes(observation_params(observation))
      o.user = current_user
      o.editing_user_id = current_user.id
      o.user_agent = request.user_agent
      unless o.site_id
        o.site = @site || current_user.site
        o.site = o.site.becomes(Site) if o.site
      end
      if doorkeeper_token && (a = doorkeeper_token.application)
        o.oauth_application = a.becomes(OauthApplication)
      elsif ( auth_header = request.headers["Authorization"] ) && ( token = auth_header.split(" ").last )
        jwt_claims = begin
          ::JsonWebToken.decode(token)
        rescue JWT::DecodeError => e
          nil
        end
        if jwt_claims && ( oauth_application_id = jwt_claims["oauth_application_id"] )
          o.oauth_application_id = oauth_application_id
        end
      end

      # We will process the photos if this is really a new observation or if the
      # client actually specified some photos. Without this, there's a
      # significant risk clients will resubmit photos without the local_photos
      # param and we'll assume its absence means the client wants to remove
      # existing photos
      if o.new_record? || !params[:local_photos].blank?
        # Get photos
        # This is kind of double-protection against deleting existing photos
        photos = o.photos
        Photo.subclasses.each do |klass|
          klass_key = klass.to_s.underscore.pluralize.to_sym
          if params[klass_key] && params[klass_key][fieldset_index]
            photos += retrieve_photos(params[klass_key][fieldset_index],
              :user => current_user, :photo_class => klass)
          end
          if params["#{klass_key}_to_sync"] && params["#{klass_key}_to_sync"][fieldset_index]
            if photo = photos.to_a.compact.last
              photo_o = photo.to_observation
              PHOTO_SYNC_ATTRS.each do |a|
                o.send("#{a}=", photo_o.send(a)) if o.send(a).blank?
              end
            end
          end
        end
        photo = photos.compact.last
        if o.new_record? && photo && photo.respond_to?(:to_observation) && !params[:uploader] &&
            (o.observed_on_string.blank? || o.latitude.blank? || o.taxon.blank?)
          photo_o = photo.to_observation
          if o.observed_on_string.blank?
            o.observed_on_string = photo_o.observed_on_string
            o.observed_on = photo_o.observed_on
            o.time_observed_at = photo_o.time_observed_at
          end
          if o.latitude.blank?
            o.latitude = photo_o.latitude
            o.longitude = photo_o.longitude
          end
          o.taxon = photo_o.taxon if o.taxon.blank?
          o.species_guess = photo_o.species_guess if o.species_guess.blank?
        end
        o.photos = ensure_photos_are_local_photos( photos )
        o.will_be_saved_with_photos = true
      end

      # Same logic we use for photos: try to avoid deleting sounds if they
      # weren't specified, but make sure we add them for new reocrds
      if o.new_record? || !params[:local_sounds].blank?
        new_sounds = Sound.from_observation_params(params, fieldset_index, current_user)
        o.sounds << ensure_sounds_are_local_sounds( new_sounds )
      end

      # make sure the obs get a valid observed_on, needed to determine research grade
      o.munge_observed_on_with_chronic
      o.set_quality_grade
      o
    end
    
    @observations.compact.each do |o|
      o.user = current_user
      # all observations will be indexed later, after all associated records
      # have been created, just before responding
      o.skip_indexing = true
      o.save
    end
    create_project_observations
    update_user_account

    # check for errors
    errors = false
    if params[:uploader]
      @observations.compact.each { |obs|
        obs.errors.delete(:project_observations)
        errors = true if obs.errors.any?
      }
    else
      @observations.compact.each { |obs| errors = true unless obs.valid? }
    end
    Observation.elastic_index!(
      ids: @observations.compact.map( &:id ),
      wait_for_index_refresh: params[:force_refresh]
    )
    respond_to do |format|
      format.html do
        unless errors
          flash[:notice] = params[:success_msg] || t(:observations_saved)
          if params[:commit] == t(:save_and_add_another)
            o = @observations.first
            redirect_to :action => 'new', 
              :latitude => o.coordinates_obscured? ? o.private_latitude : o.latitude, 
              :longitude => o.coordinates_obscured? ? o.private_longitude : o.longitude, 
              :place_guess => o.place_guess, 
              :observed_on_string => o.observed_on_string,
              :location_is_exact => o.location_is_exact,
              :map_scale => o.map_scale,
              :positional_accuracy => o.positional_accuracy,
              :positioning_method => o.positioning_method,
              :positioning_device => o.positioning_device,
              :project_id => params[:project_id]
          elsif @observations.size == 1
            redirect_to observation_path(@observations.first)
          else
            redirect_to observations_by_login_path( self.current_user.login )
          end
        else
          if @observations.size == 1
            if @project
              @place = @project.place
              @project_curators = @project.project_users.where("role IN (?)", [ProjectUser::MANAGER, ProjectUser::CURATOR])
              @tracking_code = params[:tracking_code] if @project.tracking_code_allowed?(params[:tracking_code])
              @kml_assets = @project.project_assets.select{|pa| pa.asset_file_name =~ /\.km[lz]$/}
            end
            render :action => 'new'
          else
            render :action => 'edit_batch'
          end
        end
      end
      format.json do
        if errors
          json = if @observations.size == 1 && is_iphone_app_2?
            {:error => @observations.map{|o| o.errors.full_messages}.flatten.uniq.compact.to_sentence}
          else
            {:errors => @observations.map{|o| o.errors.full_messages}}
          end
          render :json => json, :status => :unprocessable_entity
        else
          if @observations.size == 1 && is_iphone_app_2?
            render :json => @observations[0].to_json(
              :viewer => current_user,
              :methods => [:user_login, :iconic_taxon_name],
              :include => {
                :taxon => Taxon.default_json_options
              }
            )
          else
            render :json => @observations.to_json(viewer: current_user,
              methods: [ :user_login, :iconic_taxon_name, :project_observations ])
          end
        end
      end
    end
  end

  # PUT /observations/1
  # PUT /observations/1.xml
  def update
    observation_user = current_user
    
    unless params[:admin_action].nil? || !current_user.is_admin?
      observation_user = Observation.find(params[:id]).user
    end
    
    # Handle the case of a single obs
    if params[:observation]
      params[:observations] = [[params[:id], params[:observation]]]
    elsif params[:id] && params[:observations]
      params[:observations] = [[params[:id], params[:observations][0]]]
    end
    
    if params[:observations].blank? && params[:observation].blank?
      respond_to do |format|
        format.html do
          flash[:error] = t(:no_observations_submitted)
          redirect_to new_observation_path
        end
        format.json { render :status => :unprocessable_entity, :json => "No observations submitted!" }
      end
      return
    end

    @observations = params[:observations].to_h.map do |id, obs|
      Observation.where( uuid: id, user_id: observation_user ).first ||
        Observation.where( id: id, user_id: observation_user ).first
    end.compact
    
    # Make sure there's no evil going on
    unique_user_ids = @observations.map(&:user_id).uniq
    more_than_one_observer = unique_user_ids.size > 1
    admin_action = unique_user_ids.first != observation_user.id && current_user.has_role?(:admin)
    if !@observations.blank? && more_than_one_observer && !admin_action
      msg = t(:you_dont_have_permission_to_edit_that_observation)
      respond_to do |format|
        format.html do
          flash[:error] = msg
          redirect_to(@observation || observations_path)
        end
        format.json do
          render :status => :forbidden, :json => {:error => msg}
        end
      end
      return
    end
    
    # Convert the params to a hash keyed by ID.  Yes, it's weird
    hashed_params = Hash[params[:observations].to_h.map do |id, obs|
      instance = @observations.detect{ |o| o.uuid == id || o.id.to_s == id }
      instance ? [instance.id.to_s, obs] : nil
    end.compact]
    errors = false
    extra_msg = nil
    @observations.each_with_index do |observation,i|
      fieldset_index = observation.id.to_s
      observation.skip_indexing = true
      
      # Note: this ignore photos thing is a total hack and should only be
      # included if you are updating observations but aren't including flickr
      # fields, e.g. when removing something from ID please
      if !params[:ignore_photos] && !is_mobile_app?
        # Get photos
        keeper_photos = []
        old_photo_ids = observation.photo_ids
        Photo.subclasses.each do |klass|
          klass_key = klass.to_s.underscore.pluralize.to_sym
          next if klass_key.blank?
          if params[klass_key] && params[klass_key][fieldset_index]
            keeper_photos += retrieve_photos(params[klass_key][fieldset_index],
              :user => current_user, :photo_class => klass, :sync => true)
          end
        end

        if keeper_photos.empty?
          observation.observation_photos.destroy_all
        else
          keeper_photos = ensure_photos_are_local_photos( keeper_photos )
          reject_obs_photos = observation.observation_photos.select{|op| !keeper_photos.map(&:id).include?( op.photo_id )}
          reject_obs_photos.each(&:destroy)
          keeper_photos.each do |p|
            if p.new_record? || !observation.observation_photos.detect{|op| op.photo_id == p.id }
              observation.observation_photos.build( photo: p )
            end
          end
        end

        Photo.subclasses.each do |klass|
          klass_key = klass.to_s.underscore.pluralize.to_sym
          next unless params["#{klass_key}_to_sync"] && params["#{klass_key}_to_sync"][fieldset_index]
          next unless photo = observation.observation_photos.last.try(:photo)
          photo_o = photo.to_observation
          PHOTO_SYNC_ATTRS.each do |a|
            hashed_params[observation.id.to_s] ||= {}
            if hashed_params[observation.id.to_s][a].blank? && observation.send(a).blank?
              hashed_params[observation.id.to_s][a] = photo_o.send(a)
            end
          end
        end
      end

      # Kind of like :ignore_photos, but :editing_sounds makes it opt-in rather than opt-out
      # If editing sounds and no sound parameters are present, assign to an empty array 
      # This way, sounds will be removed
      if params[:editing_sounds]
        params[:soundcloud_sounds] ||= {fieldset_index => []} 
        params[:soundcloud_sounds][fieldset_index] ||= []
        params[:local_sounds] ||= {fieldset_index => []} 
        params[:local_sounds][fieldset_index] ||= []
        sounds = Sound.from_observation_params(params, fieldset_index, current_user)
        ensured_sounds = ensure_sounds_are_local_sounds( sounds )
        observation.sounds = ensured_sounds
      end
      
      observation.editing_user_id = current_user.id

      observation.force_quality_metrics = true unless hashed_params[observation.id.to_s][:captive_flag].blank?
      permitted_params = ActionController::Parameters.new( hashed_params[observation.id.to_s].to_h )
      unless observation.update( observation_params( permitted_params ) )
        errors = true
      end

      if !errors && params[:project_id] && !observation.project_observations.where(:project_id => params[:project_id]).exists?
        if @project ||= Project.find(params[:project_id])
          project_observation = ProjectObservation.create(:project => @project, :observation => observation)
          extra_msg = if project_observation.valid?
            "Successfully added to #{@project.title}"
          else
            "Failed to add to #{@project.title}: #{project_observation.errors.full_messages.to_sentence}"
          end
        end
      end
    end

    Observation.elastic_index!(
      ids: @observations.to_a.compact.map( &:id )
    )

    respond_to do |format|
      if errors
        format.html do
          if @observations.size == 1
            @observation = @observations.first
            render :action => 'edit'
          else
            render :action => 'edit_batch'
          end
        end
        format.xml  { render :xml => @observations.collect(&:errors), :status => :unprocessable_entity }
        format.json do
          render :status => :unprocessable_entity, :json => {
            :error => @observations.map{|o| o.errors.full_messages.to_sentence}.to_sentence,
            :errors => @observations.collect(&:errors)
          }
        end
      elsif @observations.empty?
        msg = if params[:id]
          t(:that_observation_no_longer_exists)
        else
          t(:those_observations_no_longer_exist)
        end
        format.html do
          flash[:error] = msg
          redirect_back_or_default(observations_by_login_path(current_user.login))
        end
        format.json { render :json => {:error => msg}, :status => :gone }
      else
        format.html do
          flash[:notice] = "#{t(:observations_was_successfully_updated)} #{extra_msg}"
          if @observations.size == 1
            redirect_to observation_path(@observations.first)
          else
            redirect_to observations_by_login_path(observation_user.login)
          end
        end
        format.xml  { head :ok }
        format.js { render :json => @observations }
        format.json do
          if @observations.size == 1 && is_iphone_app_2?
            render :json => @observations[0].to_json(
              viewer: current_user,
              methods: [:user_login, :iconic_taxon_name],
              include: {
                taxon: Taxon.default_json_options,
                observation_field_values: {},
                project_observations: {
                  include: {
                    project: {
                      only: [:id, :title, :description],
                      methods: [:icon_url]
                    }
                  }
                },
                observation_photos: {
                  include: {
                    photo: {
                      methods: [:license_code, :attribution],
                      except: [:original_url, :file_processing, :file_file_size, 
                        :file_content_type, :file_file_name, :mobile, :metadata, :user_id, 
                        :native_realname, :native_photo_id]
                    }
                  }
                },
              } )
          else
            render json: @observations.to_json( methods: [:user_login, :iconic_taxon_name], viewer: current_user )
          end
        end
      end
    end
  end
  
  def edit_photos
    @observation_photos = @observation.observation_photos
    if @observation_photos.blank?
      flash[:error] = t(:that_observation_doesnt_have_any_photos)
      return redirect_to edit_observation_path(@observation)
    end
  end
  
  def update_photos
    @observation_photos = ObservationPhoto.where(id: params[:observation_photos].to_h.map{|k,v| k})
    @observation_photos.each do |op|
      next unless @observation.observation_photo_ids.include?(op.id)
      op.update(params[:observation_photos][op.id.to_s])
    end
    
    flash[:notice] = t(:photos_updated)
    redirect_to edit_observation_path(@observation)
  end
  
  # DELETE /observations/1
  # DELETE /observations/1.xml
  def destroy
    @observation.wait_for_index_refresh = true
    @observation.destroy
    respond_to do |format|
      format.html do
        flash[:notice] = t(:observation_was_deleted)
        redirect_to(observations_by_login_path(current_user.login))
      end
      format.xml  { head :ok }
      format.json do
        head :ok
      end
    end
  end

## Custom actions ############################################################

  def curation
    @flags = Flag.where(resolved: false, flaggable_type: "Observation").
      includes(:user, :flaggable).
      paginate(page: params[:page])
  end

  def new_batch
    @step = 1
    @observations = []
    if params[:batch]
      params[:batch][:taxa].each_line do |taxon_name_str|
        next if taxon_name_str.strip.blank?
        latitude = params[:batch][:latitude]
        longitude = params[:batch][:longitude]
        @observations << Observation.new(
          :user => current_user,
          :species_guess => taxon_name_str,
          :taxon => Taxon.single_taxon_for_name(taxon_name_str.strip),
          :place_guess => params[:batch][:place_guess],
          :longitude => longitude,
          :latitude => latitude,
          :map_scale => params[:batch][:map_scale],
          :positional_accuracy => params[:batch][:positional_accuracy],
          :positioning_method => params[:batch][:positioning_method],
          :positioning_device => params[:batch][:positioning_device],
          :location_is_exact => params[:batch][:location_is_exact],
          :observed_on_string => params[:batch][:observed_on_string],
          :time_zone => current_user.time_zone)
      end
      @step = 2
    end
  end

  def new_bulk_csv
    if params[:upload].blank? || params[:upload] && params[:upload][:datafile].blank?
      flash[:error] = "You must select a CSV file to upload."
      return redirect_to :action => "import"
    end

    unique_hash = {
      :class => 'BulkObservationFile',
      :user_id => current_user.id,
      :filename => params[:upload]['datafile'].original_filename,
      :project_id => params[:upload][:project_id]
    }

    # Copy to a temp directory
    path = private_page_cache_path(File.join(
      "bulk_observation_files", 
      "#{unique_hash.to_s.parameterize}-#{Time.now}.csv"
    ))
    FileUtils.mkdir_p File.dirname(path), :mode => 0755
    File.open(path, 'wb') { |f| f.write(params[:upload]['datafile'].read) }

    unless params[:upload][:coordinate_system].blank? || @site.coordinate_systems.blank?
      if coordinate_system = @site.coordinate_systems[params[:upload][:coordinate_system]]
        proj4 = coordinate_system["proj4"]
      end
    end

    # Send the filename to a background processor
    bof = BulkObservationFile.new(
      path,
      current_user.id,
      project_id: params[:upload][:project_id], 
      coord_system: proj4
    )
    Delayed::Job.enqueue(
      bof, 
      priority: USER_PRIORITY,
      unique_hash: unique_hash,
      queue: "csv"
    )

    # Notify the user that it's getting processed and return them to the upload screen.
    flash[:notice] = 'Observation file has been queued for import.'
    if params[:upload][:project_id].blank?
      redirect_to import_observations_path
    else
      project = Project.find(params[:upload][:project_id].to_i)
      redirect_to(project_path(project))
    end
  end

  # Edit a batch of observations
  def edit_batch
    observation_ids = params[:o].is_a?(String) ? params[:o].split(',') : []
    @observations = Observation.where("id in (?) AND user_id = ?", observation_ids, current_user).
      includes(
        :quality_metrics, :observation_field_values, :sounds, :taggings,
        { observation_photos: :photo },
        { taxon: { taxon_photos: :photo } },
      )
    @observations.map do |o|
      if o.coordinates_obscured?
        o.latitude = o.private_latitude
        o.longitude = o.private_longitude
        o.place_guess = o.private_place_guess
      end
      if qm = o.quality_metrics.detect{|qm| qm.user_id == o.user_id}
        o.captive_flag = qm.metric == QualityMetric::WILD && !qm.agree? ? 1 : 0
      else
        o.captive_flag = "unknown"
      end
      o
    end
  end
  
  def delete_batch
    @observations = Observation.where(id: params[:o].split(','), user_id: current_user)
    @observations.each do |observation|
      observation.destroy if observation.user == current_user
    end
    
    respond_to do |format|
      format.html do
        flash[:notice] = t(:observations_deleted)
        redirect_to observations_by_login_path(current_user.login)
      end
      format.js { render :plain => "Observations deleted.", :status => 200 }
    end
  end
  
  # Import observations from external sources
  def import
    if @default_photo_identity ||= @photo_identities.first
      provider_name = if @default_photo_identity.is_a?(ProviderAuthorization)
        @default_photo_identity.photo_source_name
      else
        @default_photo_identity.class.to_s.underscore.split('_').first
      end
      @default_photo_identity_url = "/#{provider_name.downcase}/photo_fields?context=user"
    end
    @project = Project.find(params[:project_id].to_i) if params[:project_id]
    if logged_in?
      @projects = current_user.project_users.joins(:project).includes(:project).
        order( Arel.sql( "lower(projects.title)" ) ).collect(&:project)
      @project_templates = {}
      @projects.each do |p|
        @project_templates[p.title] = p.observation_fields.order(:position) if @project && p.id == @project.id
      end
    end
  end
  
  def import_photos
    photos = Photo.subclasses.map do |klass|
      retrieve_photos(params[klass.to_s.underscore.pluralize.to_sym], 
        :user => current_user, :photo_class => klass)
    end.flatten.compact
    @observations = photos.map do |p|
      photo_obs = p.to_observation
      if p.is_a?( PicasaPhoto )
        # Sometimes Google doesn't return all the metadata for undetermined
        # reasons. See https://github.com/inaturalist/inaturalist/issues/1408
        if photo_obs.observed_on.blank? || photo_obs.latitude.blank?
          local_photo = Photo.local_photo_from_remote_photo( p )
          photo_obs = local_photo.to_observation
          photo_obs.observation_photos.build( photo: p )
        end
      end
      photo_obs
    end
    @observation_photos = ObservationPhoto.joins(:photo, :observation).
      where("photos.native_photo_id IN (?)", photos.map(&:native_photo_id))
    @step = 2
    render :template => 'observations/new_batch'
  rescue Timeout::Error => e
    flash[:error] = t(:sorry_that_photo_provider_isnt_responding)
    Rails.logger.error "[ERROR #{Time.now}] Timeout: #{e}"
    redirect_to :action => "import"
  end

  def import_sounds
    sounds = Sound.from_observation_params(params, 0, current_user)
    @observations = sounds.map{|s| s.to_observation}
    @step = 2
    render :template => 'observations/new_batch'
  end

  def export
    if params[:flow_task_id]
      if @flow_task = ObservationsExportFlowTask.
          where( id: params[:flow_task_id], user_id: current_user ).first
        output = @flow_task.outputs.first
        @export_url = output ? helpers.uri_join(root_url, output.file.url).to_s : nil
      end
    end
    @recent_exports = ObservationsExportFlowTask.
      where( user_id: current_user ).order( id: :desc ).limit( 20 ).includes( :outputs )
    @recent_export_jobs_by_flow_task_id = @recent_exports.select{|ft| ft.outputs.blank?}.inject( {} ) do |memo, ft|
      memo[ft.id] = Delayed::Job.find_by_unique_hash( ft.enqueue_options[:unique_hash].to_s )
      memo
    end
    if params[:projects] && params[:projects].is_a?( String )
      @projects = params[:projects].to_s.split( "," ).collect{|id| Project.find( id ) rescue nil}.compact
    elsif params[:projects] && params[:projects].is_a?( Array )
      @projects = params[:projects].collect{|id| Project.find( id ) rescue nil}.compact
    end
    if @projects
      @observation_fields = @projects.collect do |proj|
        proj.project_observation_fields.collect(&:observation_field)
      end.flatten
    end
    if @observation_fields.blank?
      @observation_fields = ObservationField.recently_used_by(current_user).
        limit(50).sort_by{ |of| of.name.downcase }
    end
    set_up_instance_variables(Observation.get_search_params(params, current_user: current_user, site: @site))
    @identification_fields = if @ident_user
      %w(taxon_id taxon_name taxon_rank category).map{|a| "ident_by_#{@ident_user.login}:#{a}"}
    end
    @hide_spam = true
    respond_to do |format|
      format.html
    end
  end
  
  def add_from_list
    @order = params[:order] || "alphabetical"
    if @list = List.find_by_id(params[:id])
      @cache_key = {:controller => "observations", :action => "add_from_list", :id => @list.id, :order => @order}
      unless fragment_exist?(@cache_key)
        @listed_taxa = @list.listed_taxa.order_by(@order).includes(
          taxon: [:photos, { taxon_names: :place_taxon_names } ]).paginate(page: 1, per_page: 1000)
        @listed_taxa_alphabetical = @listed_taxa.to_a.sort! {|a,b| a.taxon.default_name.name <=> b.taxon.default_name.name}
        @listed_taxa = @listed_taxa_alphabetical if @order == ListedTaxon::ALPHABETICAL_ORDER
        @taxon_ids_by_name = {}
        ancestor_ids = @listed_taxa.map {|lt| lt.taxon.ancestry.to_s.split('/')}.flatten.uniq
        @orders = Taxon.where(rank: "order", id: ancestor_ids).order(:ancestry)
        @families = Taxon.where(rank: "family", id: ancestor_ids).order(:ancestry)
      end
    end
    @user_lists = current_user.lists.limit(100)
    
    respond_to do |format|
      format.html
      format.js do
        if fragment_exist?(@cache_key)
          render read_fragment(@cache_key)
        else
          render :partial => 'add_from_list.html.erb'
        end
      end
    end
  end
  
  def new_from_list
    @taxa = Taxon.where(id: params[:taxa]).includes(:taxon_names)
    if @taxa.blank?
      flash[:error] = t(:no_taxa_selected)
      return redirect_to :action => :add_from_list
    end
    @observations = @taxa.map do |taxon|
      current_user.observations.build(:taxon => taxon, 
        :species_guess => taxon.default_name.name,
        :time_zone => current_user.time_zone)
    end
    @step = 2
    render :new_batch
  end

  # gets observations by user login
  def by_login
    block_if_spammer(@selected_user) && return
    params[:user_id] = @selected_user.id
    params[:viewer] = current_user
    params[:filter_spam] = (current_user.blank? || current_user != @selected_user)
    params[:order_by] ||= @prefs["edit_observations_order"] if @prefs["edit_observations_order"]
    params[:order] ||= @prefs["edit_observations_sort"] if @prefs["edit_observations_sort"]
    search_params = Observation.get_search_params(params,
      current_user: current_user)
    search_params = Observation.apply_pagination_options(search_params,
      user_preferences: @prefs)
    # Since this page is really only intended for the observer, omit obscured
    # observations unless the viewer is trusted
    unless @selected_user.trusts?( current_user )
      search_params[:geoprivacy] = Observation::OPEN
      search_params[:taxon_geoprivacy] = Observation::OPEN
    end
    @observations = Observation.page_of_results(search_params)
    set_up_instance_variables(search_params)
    Observation.preload_for_component(@observations, logged_in: !!current_user)
    respond_to do |format|
      format.html do
        prepare_map(search_params)
        @observer_provider_authorizations = @selected_user.provider_authorizations
        if logged_in? && @selected_user.id == current_user.id
          @project_users = current_user.project_users.joins(:project).order("projects.title")
          if @proj_obs_errors = Rails.cache.read("proj_obs_errors_#{current_user.id}") 
            @project = Project.find_by_id(@proj_obs_errors[:project_id])
            @proj_obs_errors_obs = current_user.observations.
              where(id: @proj_obs_errors[:errors].keys).includes(:photos, :taxon)
            Rails.cache.delete("proj_obs_errors_#{current_user.id}")
          end
        end
        
        if (partial = params[:partial]) && PARTIALS.include?(partial)
          return render_observations_partial(partial)
        end
      end
      
      format.json do
        if timestamp = Chronic.parse(params[:updated_since])
          deleted_observation_ids = DeletedObservation.where("user_id = ? AND created_at >= ?", @selected_user, timestamp).
            select(:observation_id).limit(500).map(&:observation_id)
          response.headers['X-Deleted-Observations'] = deleted_observation_ids.join(',')
        end
        render_observations_to_json
      end
      
      format.kml do
        render_observations_to_kml(
          :snippet => "#{@site.name} Feed for User: #{@selected_user.login}",
          :description => "#{@site.name} Feed for User: #{@selected_user.login}",
          :name => "#{@site.name} Feed for User: #{@selected_user.login}"
        )
      end

      format.atom
      format.csv do
        render_observations_to_csv(:show_private => logged_in? && @selected_user.id == current_user.id)
      end
      format.widget do
        if params[:markup_only]=='true'
          render js: render_to_string(
            partial: "widget",
            handlers: [:erb],
            formats: [:html],
            locals: {
              show_user: false,
              target: params[:target],
              default_image: params[:default_image],
              silence:  params[:silence]
            }
          )
        else
          render js: render_to_string(
            partial: "widget",
            handlers: [:erb],
            formats: [:js]
          )
        end
      end
      
    end
  rescue Elasticsearch::Transport::Transport::Errors::InternalServerError => e
    raise e unless e.message =~ /window is too large/
    msg = "Too many results. Try using smaller searches or the id_above parameter."
    response.headers["X-Error"] = msg
    respond_to do |format|
      format.html do
        flash[:error] = msg
        redirect_to observations_by_login_path( @selected_user.login )
      end
      format.json { render json: { error: msg } }
      format.all { @observations = [] }
    end
  end

  def by_login_all
    if @selected_user.id != current_user.id
      flash[:error] = t(:you_dont_have_permission_to_do_that)
      redirect_back_or_default(root_url)
      return
    end
    path_for_csv = private_page_cache_path("observations/#{@selected_user.login}.all.csv")
    delayed_csv(path_for_csv, @selected_user)
  end
  
  # Renders observation components as form fields for inclusion in 
  # observation-picking form widgets
  def selector
    search_params = Observation.get_search_params(params,
      current_user: current_user)
    search_params = Observation.apply_pagination_options(search_params)
    @observations = Observation.latest.query(search_params).paginate(
      page: search_params[:page], per_page: search_params[:per_page])
    Observation.preload_for_component(@observations, logged_in: !!current_user)
    respond_to do |format|
      format.html { render :layout => false, :partial => 'selector'}
      # format.js
    end
  end
  
  def widget
    @project = Project.find_by_id(params[:project_id].to_i) if params[:project_id]
    @place = Place.find_by_id(params[:place_id].to_i) if params[:place_id]
    @taxon = Taxon.find_by_id(params[:taxon_id].to_i) if params[:taxon_id]
    @order_by = params[:order_by] || "observed_on"
    @order = params[:order] || "desc"
    @limit = params[:limit] || 5
    @limit = @limit.to_i
    if %w"logo-small.gif logo-small.png logo-small-white.png none".include?(params[:logo])
      @logo = params[:logo] 
    end
    @logo ||= "logo-small.gif"
    @layout = params[:layout] || "large"
    url_params = {
      :format => "widget", 
      :limit => @limit, 
      :order => @order, 
      :order_by => @order_by,
      :layout => @layout,
    }
    @widget_url = if @place
      observations_url(url_params.merge(:place_id => @place.id))
    elsif @taxon
      observations_url(url_params.merge(:taxon_id => @taxon.id))
    elsif @project
      observations_for_project_url( @project.id, url_params )
    elsif logged_in?
      observations_by_login_feed_url(current_user.login, url_params)
    end
    if @widget_url
      @widget_url.gsub!('http:', '')
    end
    respond_to do |format|
      format.html
    end
  end

  def project
    @project = Project.find(params[:id]) rescue nil
    unless @project
      flash[:error] = t(:that_project_doesnt_exist)
      redirect_to request.env["HTTP_REFERER"] || projects_path
      return
    end
    params[:projects] = @project.id
    search_params = Observation.get_search_params(params,
      current_user: current_user)
    search_params = Observation.apply_pagination_options(search_params,
      user_preferences: @prefs)
    search_params.delete(:id)
    @observations = Observation.page_of_results(search_params)
    set_up_instance_variables(search_params)
    Observation.preload_for_component(@observations, logged_in: !!current_user)
    @project_observations = @project.project_observations.where(observation: @observations.map(&:id)).
      includes([ { :curator_identification => [ :taxon, :user ] } ])
    respond_to do |format|
      format.json do
        render_observations_to_json
      end
      format.csv do
        pagination_headers_for(@observations)
        render :plain => ProjectObservation.to_csv(@project_observations, :user => current_user)
      end
      format.widget do
        if params[:markup_only] == "true"
          render js: render_to_string(
            partial: "widget",
            handlers: [:erb],
            formats: [:html],
            locals: {
              show_user: true,
              target: params[:target],
              default_image: params[:default_image],
              silence: params[:silence]
            }
          )
        else
          render js: render_to_string(
            partial: "widget",
            handlers: [:erb],
            formats: [:js],
            locals: {
              show_user: true
            }
          )
        end
      end
    end
  end
  
  def project_all
    @project = Project.find(params[:id]) rescue nil
    unless @project
      flash[:error] = t(:that_project_doesnt_exist)
      redirect_to request.env["HTTP_REFERER"] || projects_path
      return
    end
    
    unless @project.curated_by?(current_user)
      flash[:error] = t(:only_project_curators_can_do_that)
      redirect_to request.env["HTTP_REFERER"] || @project
      return
    end

    path_for_csv = private_page_cache_path("observations/project/#{@project.slug}.all.csv")
    delayed_csv(path_for_csv, @project)
  end
  
  def identify
    render layout: "bootstrap"
  end

  def upload
    render layout: "basic"
  end

  def identotron
    @observation = Observation.find_by_id((params[:observation] || params[:observation_id]).to_i)
    @taxon = Taxon.find_by_id(params[:taxon].to_i)
    @q = params[:q] unless params[:q].blank?
    if @observation
      @places = if @observation.coordinates_viewable_by?( current_user )
        @observation.places
      else
        @observation.public_places
      end
      @places = @places.sort_by{|p| p.bbox_area }
      if @observation.taxon && @observation.taxon.species_or_lower?
        @taxon ||= @observation.taxon.genus
      else
        @taxon ||= @observation.taxon
      end
      if @taxon && @places
        @place = @places.detect {|p| p.taxa.self_and_descendants_of(@taxon).exists?}
      end
    end
    @place ||= (Place.find(params[:place_id]) rescue nil) || @places.try(:first)
    @default_taxa = @taxon ? @taxon.ancestors : Taxon::ICONIC_TAXA
    @taxon ||= Taxon::LIFE
    @default_taxa = [@default_taxa, @taxon].flatten.compact
    @establishment_means = params[:establishment_means] if ListedTaxon::ESTABLISHMENT_MEANS.include?(params[:establishment_means])

    respond_to do |format|
      format.html
    end
  end

  def fields
    @project = Project.find(params[:project_id]) rescue nil
    @observation_fields = if @project
      @project.observation_fields
    elsif params[:observation_fields]
      ObservationField.where("id IN (?)", params[:observation_fields])
    else
      @observation_fields = ObservationField.recently_used_by(current_user).limit(10)
    end
    render :layout => false
  end

  def update_fields
    unless @observation.fields_addable_by?(current_user)
      respond_to do |format|
        msg = t(:you_dont_have_permission_to_do_that)
        format.html do
          flash[:error] = msg
          redirect_back_or_default @observation
        end
        format.json do
          render :status => :forbidden, :json => {:error => msg}
        end
      end
      return
    end

    if params[:observation].blank?
      respond_to do |format|
        msg = t(:you_must_choose_an_observation_field)
        format.html do
          flash[:error] = msg
          redirect_back_or_default @observation
        end
        format.json do
          render :status => :unprocessable_entity, :json => {:error => msg}
        end
      end
      return
    end

    ofv_attrs = params[:observation][:observation_field_values_attributes]
    ofv_attrs.each do |k,v|
      ofv_attrs[k][:updater_id] = current_user.id
    end
    o = { :observation_field_values_attributes =>  ofv_attrs}
    respond_to do |format|
      if @observation.update(o)
        if !params[:project_id].blank? && @observation.user_id == current_user.id && (@project = Project.find(params[:project_id]) rescue nil)
          @project_observation = @observation.project_observations.create(project: @project, user: current_user)
        end
        format.html do
          flash[:notice] = I18n.t(:observations_was_successfully_updated)
          if @project_observation && !@project_observation.valid?
            flash[:notice] += I18n.t(:however_there_were_some_issues, :issues => @project_observation.errors.full_messages.to_sentence)
          end
          redirect_to @observation
        end
        format.json do
          render :json => @observation.to_json(
            :viewer => current_user,
            :include => {
              :observation_field_values => {:include => {:observation_field => {:only => [:name]}}}
            }
          )
        end
      else
        msg = "Failed update observation: #{@observation.errors.full_messages.to_sentence}"
        format.html do
          flash[:error] = msg
          redirect_to @observation
        end
        format.json do
          render :status => :unprocessable_entity, :json => {:error => msg}
        end
      end
    end
  end

  def stats
    @headless = @footless = true
    stats_adequately_scoped?
    respond_to do |format|
      format.html
    end
  end

  def taxa
    can_view_leaves = logged_in? && current_user.is_curator?
    params[:rank] = nil unless can_view_leaves
    params[:skip_order] = true
    html_taxon_render_limit = 5000
    search_params = Observation.get_search_params(params,
      current_user: current_user)
    if stats_adequately_scoped?(search_params)
      if params[:rank] == "leaves"
        search_params.delete(:rank)
      end
      elastic_params = prepare_counts_elastic_query(search_params)
      # using 0 for the aggregation count to get all results
      limit = request.format.html? ? ( html_taxon_render_limit + 10 ) : 120000
      distinct_taxa = Observation.elastic_search(elastic_params.merge(size: 0,
        aggregate: { species: { "taxon.id": limit } })).response.aggregations
      if request.format.html? && distinct_taxa.species.buckets.length > html_taxon_render_limit
        @error = I18n.t( :too_many_taxa_to_render )
      else
        @taxa = Taxon.where(id: distinct_taxa.species.buckets.map{ |b| b["key"] })
        # if `leaves` were requested, remove any taxon in another's ancestry
        if params[:rank] == "leaves"
          ancestors = { }
          @taxa.each do |t|
            t.ancestor_ids.each do |aid|
              ancestors[aid] ||= 0
              ancestors[aid] += 1
            end
          end
          @taxa = @taxa.select{ |t| !ancestors[t.id] }
        end
      end
      # hack to test what this would look like
      @taxa = case params[:order]
      when "observations_count"
        @taxa.sort_by do |t|
          c = if search_params[:place]
            # this is a dumb hack. if i was smarter, i would have tried tp pull
            # this out of the sql with GROUP and COUNT, but I couldn't figure it
            # out --kueda 20150430
            if lt = search_params[:place].listed_taxa.where(primary_listing: true, taxon_id: t.id).first
              lt.observations_count
            else
              # if there's no listed taxon assume it's been observed once
              1
            end
          else
            t.observations_count
          end
          c.to_i * -1
        end
      when "name"
        @taxa.sort_by(&:name)
      else
        @taxa
      end
    else
      @taxa = [ ]
    end
    respond_to do |format|
      format.html do
        @headless = true
        if !@error && @taxa.length > html_taxon_render_limit
          @error = I18n.t( :too_many_taxa_to_render )
        elsif !@error
          ancestor_ids = @taxa.map{|t| t.ancestor_ids[1..-1]}.flatten.uniq
          ancestors = Taxon.where(id: ancestor_ids)
          taxa_to_arrange = (ancestors + @taxa).sort_by{|t| "#{t.ancestry}/#{t.id}"}
          @arranged_taxa = Taxon.arrange_nodes(taxa_to_arrange)
          @taxon_names_by_taxon_id = TaxonName.
            where(taxon_id: taxa_to_arrange.map(&:id).uniq).
            includes(:place_taxon_names).
            group_by(&:taxon_id)
        end
        if @error
          flash.now[:notice] = @error
        end
        render :layout => "bootstrap"
      end
      format.csv do
        Taxon.preload_associations(@taxa, { taxon_names: :place_taxon_names })
        render :plain => @taxa.to_csv(
          :only => [:id, :name, :rank, :rank_level, :ancestry, :is_active],
          :methods => [:common_name_string, :iconic_taxon_name, 
            :taxonomic_kingdom_name,
            :taxonomic_phylum_name, :taxonomic_class_name,
            :taxonomic_order_name, :taxonomic_family_name,
            :taxonomic_genus_name, :taxonomic_species_name]
        )
      end
      format.json do
        Taxon.preload_associations(@taxa, :taxon_descriptions)
        render :json => {
          :taxa => @taxa
        }
      end
    end
  end

  def taxon_stats
    params[:skip_order] = true
    search_params = Observation.get_search_params(params,
      current_user: current_user)
    if stats_adequately_scoped?(search_params) && request.format.json?
      elastic_taxon_stats(search_params)
    else
      @species_counts = [ ]
      @rank_counts = { }
    end
    @taxa = Taxon.where(id: @species_counts.map{ |r| r["taxon_id"] }).
      includes({ taxon_photos: :photo }, :taxon_names)
    @taxa_by_taxon_id = @taxa.index_by(&:id)
    @species_counts_json = @species_counts.map do |row|
      taxon = @taxa_by_taxon_id[row['taxon_id'].to_i]
      taxon.locale = I18n.locale
      {
        :count => row['count_all'],
        :taxon => taxon.as_json(
          :methods => [:default_name, :image_url, :iconic_taxon_name, :conservation_status_name],
          :only => [:id, :name, :rank, :rank_level]
        )
      }
    end
    respond_to do |format|
      format.json do
        render :json => {
          :total => @total,
          :species_counts => @species_counts_json,
          :rank_counts => @rank_counts
        }
      end
    end
  end

  def user_stats
    params[:skip_order] = true
    search_params = Observation.get_search_params(params,
      current_user: current_user)
    limit = params[:limit].to_i
    limit = 500 if limit > 500 || limit <= 0
    stats_adequately_scoped?(search_params)
    # all the HTML view needs to know is stats_adequately_scoped?
    if request.format.json?
      elastic_user_stats(search_params, limit)
      @user_ids = @user_counts.map{ |c| c["user_id"] } |
        @user_taxon_counts.map{ |c| c["user_id"] }
      @users = User.where(id: @user_ids).
        select("id, login, name, icon_file_name, icon_updated_at, icon_content_type")
      @users_by_id = @users.index_by(&:id)
    else
      @user_counts = [ ]
      @user_taxon_counts = [ ]
    end
    respond_to do |format|
      format.html do
        @headless = true
        render layout: "bootstrap"
      end
      format.json do
        render :json => {
          :total => @total,
          :most_observations => @user_counts.map{|row|
            @users_by_id[row['user_id'].to_i].blank? ? nil :
            {
              :count => row['count_all'].to_i,
              :user => @users_by_id[row['user_id'].to_i].as_json(
                :only => [:id, :name, :login],
                :methods => [:user_icon_url]
              )
            }
          }.compact,
          :most_species => @user_taxon_counts.map{|row|
            @users_by_id[row['user_id'].to_i].blank? ? nil :
            {
              :count => row['count_all'].to_i,
              :user => @users_by_id[row['user_id'].to_i].as_json(
                :only => [:id, :name, :login],
                :methods => [:user_icon_url]
              )
            }
          }.compact
        }
      end
    end
  end

  def torquemap
    @params = params.except(:controller, :action)
    render layout: "bootstrap"
  end

  def compare
    render layout: "bootstrap"
  end

  private

  def observation_params(options = {})
    p = options.blank? ? params : options
    p.permit(
      :captive_flag,
      :coordinate_system,
      :description,
      :force_quality_metrics,
      :geo_x,
      :geo_y,
      :geoprivacy,
      :iconic_taxon_id,
      :latitude,
      :license,
      :license_code,
      :location_is_exact,
      :longitude,
      :make_license_default,
      :make_licenses_same,
      :map_scale,
      :oauth_application_id,
      :observed_on_string,
      :place_guess,
      :positional_accuracy,
      :positioning_device,
      :positioning_method,
      :prefers_community_taxon,
      :quality_grade,
      :species_guess,
      :tag_list,
      :taxon_id,
      :taxon_name,
      :time_zone,
      :uuid,
      :zic_time_zone,
      :site_id,
      :owners_identification_from_vision,
      :owners_identification_from_vision_requested,
      observation_field_values_attributes: [ :_destroy, :id, :observation_field_id, :value ]
    )
  end

  def user_obs_counts(scope, limit = 500)
    user_counts_sql = <<-SQL
      SELECT
        o.user_id,
        count(*) AS count_all
      FROM
        (#{scope.to_sql}) AS o
      GROUP BY
        o.user_id
      ORDER BY count_all desc
      LIMIT #{limit}
    SQL
    ActiveRecord::Base.connection.execute(user_counts_sql)
  end

  def user_taxon_counts(scope, limit = 500)
    unique_taxon_users_scope = scope.
      select("DISTINCT observations.taxon_id, observations.user_id").
      joins(:taxon).
      where("taxa.rank_level <= ?", Taxon::SPECIES_LEVEL)
    user_taxon_counts_sql = <<-SQL
      SELECT
        o.user_id,
        count(*) AS count_all
      FROM
        (#{unique_taxon_users_scope.to_sql}) AS o
      GROUP BY
        o.user_id
      ORDER BY count_all desc
      LIMIT #{limit}
    SQL
    ActiveRecord::Base.connection.execute(user_taxon_counts_sql)
  end
  public

  def viewed_updates
    user_viewed_updates
    respond_to do |format|
      format.html { redirect_to @observation }
      format.json { head :no_content }
    end
  end

  def review
    user_reviewed
    respond_to do |format|
      format.html { redirect_to @observation }
      format.json do
        head :no_content
      end
    end
  end

  def email_export
    unless flow_task = current_user.flow_tasks.find_by_id(params[:id])
      render status: :unprocessable_entity, plain: "Flow task doesn't exist"
      return
    end
    if flow_task.user_id != current_user.id
      render status: :forbidden, plain: "You don't have permission to do that"
      return
    end
    if flow_task.outputs.exists?
      Emailer.observations_export_notification(flow_task).deliver_now
      render status: :ok, plain: ""
      return
    elsif flow_task.error
      Emailer.observations_export_failed_notification(flow_task).deliver_now
      render status: :ok, plain: ""
      return
    end
    flow_task.options = flow_task.options.merge(:email => true)
    if flow_task.save
      render status: :ok, plain: ""
    else
      render status: :unprocessable_entity, plain: flow_task.errors.full_messages.to_sentence
    end
  end

  def community_taxon_summary
    render :layout => false, :partial => "community_taxon_summary"
  end

  def map
    @taxa = [ ]
    @places = [ ]
    @user = User.find_by_id(params[:user_id])
    @project = Project.find(params[:project_id]) rescue nil
    if params[:taxon_id]
      @taxa = [ Taxon.find_by_id(params[:taxon_id].to_i) ]
    elsif params[:taxon_ids]
      @taxa = Taxon.where(id: params[:taxon_ids])
    end
    if params[:place_id]
      @places = [ Place.find_by_id(params[:place_id].to_i) ]
    elsif params[:place_ids]
      @places = Place.where(id: params[:place_ids])
    end
    if params[:render_place_id]
      @render_place = Place.find_by_id(params[:render_place_id])
    end
    if @taxa.length == 1
      @taxon = @taxa.first
      @taxon_hash = { }
      common_name = view_context.common_taxon_name( @taxon, user: current_user ).try(:name)
      rank_label = @taxon.rank ? t('ranks.#{ @taxon.rank.downcase }',
        default: @taxon.rank).capitalize : t(:unknown_rank)
      display_name = common_name || (rank_label + " " + @taxon.name)
      @taxon_hash[:display_label] = I18n.t(:observations_of_taxon,
        taxon_name: display_name)
      if @taxon.iconic_taxon
        @taxon_hash[:iconic_taxon_name] = @taxon.iconic_taxon.name
      end
    end
    @elastic_params = valid_map_params
    @default_color = params[:color] || (@taxa.empty? ? "heatmap" : nil)
    @map_style = (( params[:color] || @taxa.any? ) &&
                    params[:color] != "heatmap" ) ? "grid" : "heatmap"
    @map_type = ( params[:type] == "map" ) ? "MAP" : "SATELLITE"
    @default_color = params[:heatmap_colors] if @map_style == "heatmap"
    @about_url = @site.map_about_url.blank? ? view_context.wiki_page_url('help', anchor: 'mapsymbols') : @site.map_about_url
  end

  def observation_links
    render json: @observation.observation_links
  end

## Protected / private actions ###############################################
  private

  def user_viewed_updates(options={})
    return unless logged_in?
    if options[:delay]
      ActiveRecord::Base.connection.without_sticking do
        @observation.delay(priority: USER_PRIORITY).user_viewed_updates(current_user.id)
      end
    else
      @observation.user_viewed_updates(current_user.id)
    end
  end

  def user_reviewed
    return unless logged_in?
    review = ObservationReview.where(observation_id: @observation.id,
      user_id: current_user.id).first_or_create
    reviewed = if request.delete?
      false
    else
      params[:reviewed] === "false" ? false : true
    end
    review.update({ user_added: true, reviewed: reviewed })
    review.update_observation_index( wait_for_refresh: params[:wait_for_refresh] )
  end

  def stats_adequately_scoped?(search_params = { })
    # use the supplied search_params if available. Those will already have
    # tried to resolve and instances referred to by ID
    stats_params = search_params.blank? ? params : search_params
    if stats_params[:d1]
      d1 = (Date.parse(stats_params[:d1]) rescue Date.today)
      d2 = stats_params[:d2] ? (Date.parse(stats_params[:d2]) rescue Date.today) : Date.today
      return false if d2 - d1 > 366
    end
    @stats_adequately_scoped = !(
      stats_params[:d1].blank? &&
      stats_params[:projects].blank? &&
      stats_params[:place_id].blank? &&
      stats_params[:user_id].blank? &&
      stats_params[:on].blank? &&
      stats_params[:created_on].blank? &&
      stats_params[:apply_project_rules_for].blank?
    )
  end
  
  def retrieve_photos(photo_list = nil, options = {})
    return [] if photo_list.blank?
    photo_list = photo_list.values if photo_list.is_a?(Hash)
    photo_list = [photo_list] unless photo_list.is_a?(Array)
    photo_class = options[:photo_class] || Photo
    
    # simple algorithm,
    # 1. create an array to be passed back to the observation obj
    # 2. check to see if that photo's data has already been stored
    # 3. if yes
    #      retrieve Photo obj and put in array
    #    if no
    #      create Photo obj and put in array
    # 4. return array
    photos = []
    native_photo_ids = photo_list.map{|p| p.to_s}.uniq
    # the photos may exist in their native photo_class, or cached
    # as a LocalPhoto, so lookup both and combine results
    existing = LocalPhoto.where( subtype: photo_class.name, native_photo_id: native_photo_ids, user_id: current_user.id )
    if photo_class && photo_class != LocalPhoto
      existing += photo_class.includes(:user).where( native_photo_id: native_photo_ids, user_id: current_user.id )
    end
    existing = existing.index_by{|p| p.native_photo_id }
    photo_list.uniq.each do |photo_id|
      if (photo = existing[photo_id]) || options[:sync]
        api_response = begin
          photo_class.get_api_response(photo_id, :user => current_user)
        rescue JSON::ParserError => e
          Rails.logger.error "[ERROR #{Time.now}] Failed to parse JSON from Flickr: #{e}"
          next
        end
      end
      
      # Sync existing if called for
      if photo
        photo.user ||= options[:user]
        if options[:sync]
          # sync the photo URLs b/c they change when photos become private
          photo.api_response = api_response # set to make sure user validation works
          photo.sync
          photo.save if photo.changed?
        end
      end
      
      # Create a new one if one doesn't already exist
      unless photo
        photo = if photo_class == LocalPhoto
          if photo_id.is_a?(Integer) || photo_id.is_a?(String)
            LocalPhoto.find_by_id(photo_id)
          elsif !photo_id.blank?
            LocalPhoto.new( file: photo_id, user: current_user) unless photo_id.blank?
          end
        else
          api_response ||= begin
            photo_class.get_api_response(photo_id, :user => current_user)
          rescue JSON::ParserError => e
            Rails.logger.error "[ERROR #{Time.now}] Failed to parse JSON from Flickr: #{e}"
            nil
          end
          if api_response
            photo_class.new_from_api_response(api_response, :user => current_user, :native_photo_id => photo_id)
          end
        end
      end

      if photo.blank?
        Rails.logger.error "[ERROR #{Time.now}] Failed to get photo for photo_class: #{photo_class}, photo_id: #{photo_id}"
      elsif photo.valid? || existing[photo_id]
        photos << photo
      else
        Rails.logger.error "[ERROR #{Time.now}] #{current_user} tried to save an observation with a new invalid photo (#{photo}): #{photo.errors.full_messages.to_sentence}"
      end
    end
    photos
  end

  def set_up_instance_variables(search_params)
    @swlat = search_params[:swlat] unless search_params[:swlat].blank?
    @swlng = search_params[:swlng] unless search_params[:swlng].blank?
    @nelat = search_params[:nelat] unless search_params[:nelat].blank?
    @nelng = search_params[:nelng] unless search_params[:nelng].blank?
    if search_params[:place].is_a?(Array) && search_params[:place].length == 1
      search_params[:place] = search_params[:place].first
    end
    unless search_params[:place].blank? || search_params[:place].is_a?(Array)
      @place = search_params[:place]
    end
    if search_params[:not_in_place_record].is_a?(Array) && search_params[:not_in_place_record].length == 1
      search_params[:not_in_place_record] = search_params[:not_in_place_record].first
    end
    unless search_params[:not_in_place_record].blank? || search_params[:not_in_place_record].is_a?(Array)
      @not_in_place_record = search_params[:not_in_place_record]
    end
    @lat = search_params[:lat]
    @lng = search_params[:lng]
    @radius = search_params[:radius]
    @q = search_params[:q] unless search_params[:q].blank?
    @search_on = search_params[:search_on]
    @iconic_taxa = search_params[:iconic_taxa_instances]
    @observations_taxon_id = search_params[:observations_taxon_id]
    @observations_taxon = search_params[:observations_taxon]
    @without_observations_taxon = search_params[:without_observations_taxon]
    @observations_taxon_name = search_params[:taxon_name]
    @observations_taxon_ids = search_params[:taxon_ids] || search_params[:observations_taxon_ids]
    @observations_taxa = search_params[:observations_taxa]
    search_params[:has] ||= [ ]
    search_params[:has] << "photos" if search_params[:photos].yesish?
    search_params[:has] << "sounds" if search_params[:sounds].yesish?
    if search_params[:has]
      @id_please = true if search_params[:has].include?('id_please')
      @with_photos = true if search_params[:has].include?('photos')
      @with_sounds = true if search_params[:has].include?('sounds')
      @with_geo = true if search_params[:has].include?('geo')
    end
    @quality_grade = search_params[:quality_grade]
    @reviewed = search_params[:reviewed]
    @captive = search_params[:captive]
    @identifications = search_params[:identifications]
    @license = search_params[:license]
    @photo_license = search_params[:photo_license]
    @sound_license = search_params[:sound_license]
    @order_by = search_params[:order_by]
    @order = search_params[:order]
    @observed_on = search_params[:observed_on]
    @observed_on_year = search_params[:observed_on_year]
    @observed_on_month = [ search_params[:observed_on_month] ].flatten.first
    @observed_on_day = search_params[:observed_on_day]
    @ofv_params = search_params[:ofv_params]
    @site_uri = params[:site] unless params[:site].blank?
    @user = search_params[:user]
    @projects = search_params[:projects]
    @pcid = search_params[:pcid]
    @geoprivacy = search_params[:geoprivacy] unless search_params[:geoprivacy].blank?
    @taxon_geoprivacy = search_params[:taxon_geoprivacy] unless search_params[:taxon_geoprivacy].blank?
    @rank = search_params[:rank]
    @hrank = search_params[:hrank]
    @lrank = search_params[:lrank]
    @verifiable = search_params[:verifiable]
    @threatened = search_params[:threatened]
    @introduced = search_params[:introduced]
    @native = search_params[:native]
    @popular = search_params[:popular]
    @spam = search_params[:spam]
    if stats_adequately_scoped?(search_params)
      @d1 = search_params[:d1].blank? ? nil : search_params[:d1]
      @d2 = search_params[:d2].blank? ? nil : search_params[:d2]
    else
      search_params[:d1] = nil
      search_params[:d2] = nil
    end
    unless search_params[:ident_user_id].blank?
      @ident_user = User.find_by_id( search_params[:ident_user_id] )
      @ident_user ||= User.find_by_login( search_params[:ident_user_id] )
    end
    @misc_hidden_parameters = %w(
      id
      ident_taxon_id
      identified
      term_id
      term_value_id
    )
    
    @filters_open = 
      !@q.nil? ||
      !@observations_taxon_id.blank? ||
      !@observations_taxon_name.blank? ||
      !@without_observations_taxon.blank? ||
      !@iconic_taxa.blank? ||
      @id_please == true ||
      !@with_photos.blank? ||
      !@with_sounds.blank? ||
      !@identifications.blank? ||
      !@quality_grade.blank? ||
      !@captive.blank? ||
      !@observed_on.blank? ||
      !@place.blank? ||
      !@ofv_params.blank? ||
      !@pcid.blank? ||
      !@geoprivacy.blank? ||
      !@rank.blank? ||
      !@lrank.blank? ||
      !@hrank.blank?
    @filters_open = search_params[:filters_open] == 'true' if search_params.has_key?(:filters_open)
  end

  # Tries to create a new observation from the specified Flickr photo ID and
  # update the existing @observation with the new properties, without saving
  def sync_flickr_photo
    flickr = get_flickr
    begin
      fp = flickr.photos.getInfo(:photo_id => params[:flickr_photo_id])
      @flickr_photo = FlickrPhoto.new_from_flickr(fp, :user => current_user)
    rescue Flickr::FailedResponse => e
      Rails.logger.debug "[DEBUG] Flickr failed to find photo " +
        "#{params[:flickr_photo_id]}: #{e}\n#{e.backtrace.join("\n")}"
      @flickr_photo = nil
    rescue Timeout::Error => e
      flash.now[:error] = t(:sorry_flickr_isnt_responding_at_the_moment)
      Rails.logger.error "[ERROR #{Time.now}] Timeout: #{e}"
      Logstasher.write_exception(e, request: request, session: session, user: current_user)
      return
    end
    if fp && @flickr_photo && @flickr_photo.valid?
      @flickr_observation = @flickr_photo.to_observation
      sync_attrs = %w(description species_guess taxon_id observed_on 
        observed_on_string latitude longitude place_guess map_scale tag_list)
      unless params[:flickr_sync_attrs].blank?
        sync_attrs = sync_attrs & params[:flickr_sync_attrs]
      end
      sync_attrs.each do |sync_attr|
        # merge flickr_observation with existing observation
        val = @flickr_observation.send(sync_attr)
        @observation.send("#{sync_attr}=", val) unless val.blank?
      end
      
      # Note: the following is sort of a hacky alternative to build().  We
      # need to append a new photo object without saving it, but build() won't
      # work here b/c Photo and its descedents use STI, and type is a
      # protected attributes that can't be mass-assigned.
      photo_already_exists = @observation.observation_photos.detect do |op|
        op.photo.native_photo_id == @flickr_photo.native_photo_id &&
        op.photo.subclass == "FlickrPhoto"
      end
      unless photo_already_exists
        @observation.observation_photos.build(:photo => @flickr_photo)
      end
      
      unless @observation.new_record?
        flash.now[:notice] = t(:preview_of_synced_observation, :url => url_for)
      end
      
      if (@existing_photo = LocalPhoto.where( subtype: "FlickrPhoto", native_photo_id: @flickr_photo.native_photo_id ) ) &&
          (@existing_photo_observation = @existing_photo.observations.first) && @existing_photo_observation.id != @observation.id
        msg = t(:heads_up_this_photo_is_already_associated_with, :url => url_for(@existing_photo_observation))
        flash.now[:notice] = flash.now[:notice].blank? ? msg : "#{flash.now[:notice]}<br/>#{msg}"
      end
    else
      flash.now[:error] = t(:sorry_we_didnt_find_that_photo)
    end
  end
  
  def sync_picasa_photo
    begin
      api_response = PicasaPhoto.get_api_response(params[:picasa_photo_id], :user => current_user)
    rescue Timeout::Error => e
      flash.now[:error] = t(:sorry_picasa_isnt_responding_at_the_moment)
      Rails.logger.error "[ERROR #{Time.now}] Timeout: #{e}"
      Logstasher.write_exception(e, request: request, session: session, user: current_user)
      return
    end
    unless api_response
      Rails.logger.debug "[DEBUG] Failed to find Picasa photo for #{params[:picasa_photo_id]}"
      return
    end
    @picasa_photo = PicasaPhoto.new_from_api_response(api_response, :user => current_user)
    
    if @picasa_photo && @picasa_photo.valid?
      @picasa_observation = @picasa_photo.to_observation
      sync_attrs = PHOTO_SYNC_ATTRS
      unless params[:picasa_sync_attrs].blank?
        sync_attrs = sync_attrs & params[:picasa_sync_attrs]
      end
      sync_attrs.each do |sync_attr|
        @observation.send("#{sync_attr}=", @picasa_observation.send(sync_attr))
      end
      photo_already_exists = @observation.observation_photos.detect do |op|
        op.photo.native_photo_id == @picasa_photo.native_photo_id &&
        op.photo.subclass == "PicasaPhoto"
      end
      unless photo_already_exists
        @observation.observation_photos.build(:photo => @picasa_photo)
      end
      
      flash.now[:notice] = t(:preview_of_synced_observation, :url => url_for)
    else
      flash.now[:error] = t(:sorry_we_didnt_find_that_photo)
    end
  end

  def sync_local_photo
    unless @local_photo = Photo.find_by_id(params[:local_photo_id])
      flash.now[:error] = t(:that_photo_doesnt_exist)
      return
    end
    if @local_photo.metadata.blank?
      flash.now[:error] = t(:sorry_we_dont_have_any_metadata_for_that_photo)
      return
    end
    o = @local_photo.to_observation
    PHOTO_SYNC_ATTRS.each do |sync_attr|
      @observation.send("#{sync_attr}=", o.send(sync_attr)) unless o.send(sync_attr).blank?
    end

    unless @observation.observation_photos.detect {|op| op.photo_id == @local_photo.id}
      @observation.observation_photos.build(:photo => @local_photo)
    end
    
    unless @observation.new_record?
      flash.now[:notice] = t(:preview_of_synced_observation, :url => url_for)
    end
    
    if @existing_photo_observation = @local_photo.observations.where( "observations.id != ?", @observation.id ).first
      msg = t(:heads_up_this_photo_is_already_associated_with, :url => url_for(@existing_photo_observation))
      flash.now[:notice] = flash.now[:notice].blank? ? msg : "#{flash.now[:notice]}<br/>#{msg}"
    end
  end
  
  def load_photo_identities
    return if @skipping_preloading
    unless logged_in?
      @photo_identity_urls = []
      @photo_identities = []
      return true
    end
    if Rails.env.development?
      PicasaPhoto
      LocalPhoto
      FlickrPhoto
    end
    @photo_identities = Photo.subclasses.map do |klass|
      assoc_name = klass.to_s.underscore.split('_').first + "_identity"
      current_user.send(assoc_name) if current_user.respond_to?(assoc_name)
    end.compact
    reference_photo = @observation.try(:observation_photos).try(:first).try(:photo)
    reference_photo ||= @observations.try(:first).try(:observation_photos).try(:first).try(:photo)
    unless params[:action] === "show" || params[:action] === "update"
      if reference_obs = Observation.elastic_query( user_id: current_user.id, per_page: 1, has_photos: true ).first
        reference_photo = reference_obs.photos.first
      end
    end
    if reference_photo
      assoc_name = (reference_photo.subtype || reference_photo.class.to_s).
        underscore.split('_').first + "_identity"
      if current_user.respond_to?(assoc_name)
        @default_photo_identity = current_user.send(assoc_name)
      else
        @default_photo_source = 'local'
      end
    end
    if params[:flickr_photo_id]
      if @default_photo_identity = @photo_identities.detect{|pi| pi.to_s =~ /flickr/i}
        @default_photo_source = 'flickr'
      end
    end
    @default_photo_source ||= if @default_photo_identity
      if @default_photo_identity.class.name =~ /Identity/
        @default_photo_identity.class.name.underscore.humanize.downcase.split.first
      else
        @default_photo_identity.provider_name
      end
    elsif @default_photo_identity
      "local"
    end
    
    @default_photo_identity_url = nil
    @photo_identity_urls = @photo_identities.map do |identity|
      provider_name = nil
      provider_type = nil
      if identity.is_a?(ProviderAuthorization)
        if identity.provider_name =~ /google/i
          provider_type = "picasa"
          provider_name = "Google Photos"
        else
          provider_type = identity.provider_name
        end
      else
        provider_type = identity.class.to_s.underscore.split('_').first # e.g. FlickrIdentity=>'flickr'
      end
      provider_name ||= provider_type
      url = "/#{provider_type.downcase}/photo_fields?context=user"
      @default_photo_identity_url = url if identity == @default_photo_identity
      "{title: '#{provider_name.titleize}', url: '#{url}'}"
    end
    @photo_sources = @photo_identities.inject({}) do |memo, ident| 
      if ident.respond_to?(:source_options)
        memo[ident.class.name.underscore.humanize.downcase.split.first] = ident.source_options
      elsif ident.is_a?(ProviderAuthorization)
        if ident.provider_name =~ /google/
          memo[:picasa] = {
            :title => 'Google Photos', 
            :url => '/picasa/photo_fields', 
            :contexts => [
              ["Your photos", 'user', {:searchable => true}]
            ]
          }
        end
      end
      memo
    end
  end

  def load_sound_identities
    return if @skipping_preloading
    unless logged_in?
      logger.info "not logged in"
      @sound_identities = []
      return true
    end

    @sound_identities = current_user.soundcloud_identity ? [current_user.soundcloud_identity] : []
  end
  
  def load_observation
    obs_id = params[:id] || params[:observation_id]
    scope = if obs_id.to_s =~ BelongsToWithUuid::UUID_PATTERN
      Observation.where( uuid: obs_id )
    else
      scope = Observation.where( id: obs_id )
    end
    includes = [ :quality_metrics,
      :flags,
      { photos: :flags },
      :sounds,
      :identifications,
      :projects,
      { taxon: :taxon_names }
    ]
    scope = scope.includes( includes ) unless @skipping_preloading
    @observation = begin
      scope.first
    rescue RangeError => e
      Logstasher.write_exception(e, request: request, session: session, user: current_user)
      nil
    end
    unless @observation
      uuid_scope = Observation.where( uuid: params[:id] )
      uuid_scope = uuid_scope.includes( includes ) unless @skipping_preloading
      @observation = uuid_scope.first
    end
    render_404 unless @observation
  end

  def search_taxon
    return if params[:taxon_id].blank?

    @search_taxon ||= Taxon.find_by_id(params[:taxon_id].to_i)
  end

  def search_place
    return if params[:place_id].blank?

    @search_place ||= Place.find_by_id( params[:place_id].to_i )
  end

  def search_user
    return if params[:user_id].blank?

    @search_user ||= ( User.find_by_id( params[:user_id].to_i ) || User.find_by_login( params[:user_id] ) )
  end
  
  def search_date
    return if params[:on].blank?

    begin
      @search_date ||= Date.parse( params[:on] )
    rescue ArgumentError
      nil
    end
  end

  def generate_shareable_description
    if search_taxon
      key = "observation_brief_taxon"
      i18n_vars = {}
      i18n_vars[:taxon] = search_taxon.common_name( locale: I18n.locale ).try(:name)
      i18n_vars[:taxon] = search_taxon.name if i18n_vars[:taxon].blank?
      if search_place
        key += "_from_place"
        i18n_vars[:place] = search_place.localized_name
      end
      if search_date
        key += "_on_day"
        i18n_vars[:day] = I18n.l( search_date, format: :long )
      end
      if search_user
        key += "_by_user"
        i18n_vars[:user] = search_user.try_methods(:name, :login)
      end
      I18n.t( key, **i18n_vars.merge( default: I18n.t( :observations_of_taxon, taxon_name: i18n_vars[:taxon] ) ) )
    elsif search_user
      if search_date
        I18n.t( :observations_by_user_on_date, user: search_user.try_methods(:name, :login), date: I18n.l( search_date, format: :long ) )
      else
        I18n.t( :observations_by_user, user: search_user.try_methods(:name, :login) )
      end
    else
      I18n.t( :x_site_is_a_social_network_for_naturalist, site: @site.name )
    end
  end

  def require_owner
    unless ( logged_in? && current_user.id == @observation.user_id ) || current_user.is_admin?
      msg = t(:you_dont_have_permission_to_do_that)
      respond_to do |format|
        format.html do
          flash[:error] = msg
          return redirect_to @observation
        end
        format.json do
          return render :json => {:error => msg}, status: :forbidden
        end
      end
    end
  end
  
  def render_observations_to_json(options = {})
    if (partial = params[:partial]) && PARTIALS.include?(partial)
      Observation.preload_associations(@observations, [
        :stored_preferences,
        { :taxon => :taxon_descriptions },
        { :iconic_taxon => :taxon_descriptions } ])
      data = @observations.map do |observation|
        item = {
          :instance => observation,
          :extra => {
            :taxon => observation.taxon,
            :iconic_taxon => observation.iconic_taxon,
            :user => {login: observation.user.login, name: observation.user.name}
          }
        }
        item[:html] = view_context.render_in_format(:html, :partial => partial, :object => observation)
        item
      end
      render :json => data
    else
      opts = options
      opts[:methods] ||= []
      opts[:methods] += [:short_description, :user_login, :iconic_taxon_name, :tag_list, :faves_count]
      opts[:methods].uniq!
      opts[:include] ||= {}
      opts[:include][:taxon] ||= {
        :only => [:id, :name, :rank, :ancestry],
        :methods => [:common_name]
      }
      opts[:include][:iconic_taxon] ||= {:only => [:id, :name, :rank, :rank_level, :ancestry]}
      opts[:include][:user] ||= {:only => :login, :methods => [:user_icon_url]}
      opts[:include][:photos] ||= {
        :methods => [:license_code, :attribution],
        :except => [:original_url, :file_processing, :file_file_size, 
          :file_content_type, :file_file_name, :mobile, :metadata]
      }
      extra = params[:extra].to_s.split(',')
      if extra.include?('projects')
        opts[:include][:project_observations] ||= {
          :include => {:project => {:only => [:id, :title]}},
          :except => [:tracking_code]
        }
      end
      if extra.include?('observation_photos')
        opts[:include][:observation_photos] ||= {
          :include => {:photo => {:except => [:metadata]}}
        }
      end
      if extra.include?('identifications')
        taxon_options = Taxon.default_json_options
        taxon_options[:methods] += [:iconic_taxon_name, :image_url, :common_name, :default_name]
        opts[:include][:identifications] ||= {
          'include': {
            user: {
              only: [:name, :login, :id],
              methods: [:user_icon_url]
            },
            taxon: {
              only: [:id, :name, :rank, :rank_level],
              methods: [:iconic_taxon_name, :image_url, :common_name, :default_name]
            }
          }
        }
      end
      if @ofv_params || extra.include?('fields')
        opts[:include][:observation_field_values] ||= {
          :except => [:observation_field_id],
          :include => {
            :observation_field => {
              :only => [:id, :datatype, :name, :allowed_values]
            }
          }
        }
      end
      pagination_headers_for(@observations)
      opts[:viewer] = current_user
      if @observations.respond_to?(:scoped)
        Observation.preload_associations(@observations, [ {:observation_photos => { :photo => :user } }, :photos, :iconic_taxon ])
      end
      @observations.each do |o|
        if o.taxon && current_user
          o.taxon.current_user = current_user
        end
        o.localize_place = current_user.try(:place) || @site.place
        o.localize_locale = current_user.try(:locale) || @site.locale
      end
      render :json => @observations.to_json(opts)
    end
  end
  
  def render_observations_to_csv(options = {})
    first = %w(scientific_name datetime description place_guess latitude longitude tag_list common_name url image_url user_login)
    only = (first + Observation::CSV_COLUMNS).uniq
    except = %w(map_scale timeframe iconic_taxon_id delta geom user_agent cached_tag_list)
    unless options[:show_private] == true
      except += %w(private_latitude private_longitude private_place_guess)
    end
    only = only - except
    unless @ofv_params.blank?
      only += @ofv_params.map{|k,v| "field:#{v[:normalized_name]}"}
      if @observations.respond_to?(:scoped)
        Observation.preload_associations(@observations, { :observation_field_values => :observation_field })
      end
    end
    Observation.preload_associations(@observations, [ :tags, :taxon, :photos, :user, :quality_metrics ])
    pagination_headers_for(@observations)
    render :plain => Observation.as_csv(@observations, only.map{|c| c.to_sym},
      { ssl: request.protocol =~ /https/ })
  end
  
  def render_observations_to_kml(options = {})
    @net_hash = options
    if params[:kml_type] == "network_link"
      kml_query = request.query_parameters.reject{|k,v| REJECTED_KML_FEED_PARAMS.include?(k.to_s) || k.to_s == "kml_type"}.to_query
      kml_href = "#{request.base_url}#{request.path}"
      kml_href += "?#{kml_query}" unless kml_query.blank?
      @net_hash = {
        :id => "AllObs", 
        :link_id =>"AllObs", 
        :snippet => "#{@site.name} Feed for Everyone",
        :description => "#{@site.name} Feed for Everyone",
        :name => "#{@site.name} Feed for Everyone",
        :href => kml_href
      }
      render :layout => false, :action => 'network_link'
      return
    end
    render :layout => false, :action => "index"
  end
  
  # create project observations if a project was specified and project allows 
  # auto-joining
  def create_project_observations
    return unless params[:project_id]
    if params[:project_id].is_a?(Array)
      params[:project_id].each do |pid|
        errors = create_project_observation_records(pid)
      end
    else
      errors = create_project_observation_records(params[:project_id])
      if !errors.blank?
        if request.format.html?
          flash[:error] = t(:your_observations_couldnt_be_added_to_that_project, :errors => errors.to_sentence)
        else
          Rails.logger.error "[ERROR #{Time.now}] Failed to add #{@observations.size} obs to #{@project}: #{errors.to_sentence}"
        end
      end
    end
  end

  def create_project_observation_records(project_id)
    return unless project_id
    @project = Project.find_by_id(project_id)
    @project ||= Project.find(project_id) rescue nil
    return unless @project
    if @project.tracking_code_allowed?(params[:tracking_code])
      tracking_code = params[:tracking_code]
    end
    errors = []
    @observations.each do |observation|
      next if observation.new_record?
      observation.reload
      po = observation.project_observations.build(project: @project,
        tracking_code: tracking_code, user: current_user)
      unless po.save
        if params[:uploader]
          observation.project_observations.delete(po)
        end
        return (errors + po.errors.full_messages).uniq
      end
    end
    nil
  end
  
  def update_user_account
    current_user.update(params[:user]) unless params[:user].blank?
  end
  
  def render_observations_partial(partial)
    if @observations.empty?
      render(:plain => '')
    else
      render(partial: "partial_renderer",
        locals: { partial: partial, collection: @observations }, layout: false)
    end
  end

  def load_prefs
    @prefs = current_preferences
    if request.format && request.format.html?
      @view = params[:view] || current_user.try(:preferred_observations_view) || 'map'
    end
  end

  def delayed_csv(path_for_csv, parent, options = {})
    if parent.observations.count < 50
      Observation.generate_csv_for(parent, :path => path_for_csv, :user => current_user)
      render :file => path_for_csv, :formats => [:csv]
    else
      cache_key = Observation.generate_csv_for_cache_key(parent)
      job_id = Rails.cache.read(cache_key)
      job = Delayed::Job.find_by_id(job_id)
      if job
        # Still working
      elsif File.exists? path_for_csv
        render :file => path_for_csv, :formats => [:csv]
        return
      else
        # no job id, no job, let's get this party started
        Rails.cache.delete(cache_key)
        job = Observation.delay(
          priority: NOTIFICATION_PRIORITY,
          queue: "csv",
          unique_hash: "Observations::delayed_csv::#{cache_key}"
        ).generate_csv_for( parent, path: path_for_csv, user: current_user )
        Rails.cache.write(cache_key, job.id, :expires_in => 1.hour)
      end
      prevent_caching
      render :status => :accepted, :plain => "This file takes a little while to generate. It should be ready shortly at #{request.url}"
    end
  end

  def elastic_taxon_stats(search_params)
    if search_params[:rank] == "leaves"
      search_params.delete(:rank)
      showing_leaves = true
    end
    elastic_params = prepare_counts_elastic_query(search_params)
    taxon_counts = Observation.elastic_search(elastic_params.merge(size: 0,
      aggregate: {
        distinct_taxa: { cardinality: { field: "taxon.id", precision_threshold: 10000 } },
        rank: {
          terms: {
            field: "taxon.rank", size: 30,
            order: { "distinct_taxa": :desc } },
          aggs: {
            distinct_taxa: {
              cardinality: { field: "taxon.id", precision_threshold: 10000 } } } }
      })).response.aggregations
    @total = taxon_counts.distinct_taxa.value
    @rank_counts = Hash[ taxon_counts.rank.buckets.
      map{ |b| [ b["key"], b["distinct_taxa"]["value"] ] } ]
    elastic_params[:filters] << { range: {
      "taxon.rank_level" => { lte: Taxon::RANK_LEVELS["species"] } } }
    species_counts = Observation.elastic_search(elastic_params.merge(size: 0,
      aggregate: { species: { "taxon.id": 100 } })).response.aggregations
    # the count is a string to maintain backward compatibility
    @species_counts = species_counts.species.buckets.
      map{ |b| { "taxon_id" => b["key"], "count_all" => b["doc_count"].to_s } }
    if showing_leaves
      leaf_ids = Observation.elastic_taxon_leaf_ids(prepare_counts_elastic_query(search_params))
      @rank_counts[:leaves] = leaf_ids.count
      # we fetch extra taxa above so we can safely filter
      # out the non-leaf taxa from the result
      @species_counts.delete_if{ |s| !leaf_ids.include?(s["taxon_id"]) }
    end
    # limit the species_counts to 5
    @species_counts = @species_counts[0...5]
  end

  def elastic_user_stats(search_params, limit)
    elastic_params = prepare_counts_elastic_query(search_params)
    user_obs = Observation.elastic_user_observation_counts(elastic_params, limit)
    @user_counts = user_obs[:counts]
    @total = user_obs[:total]
    @user_taxon_counts = Observation.elastic_user_taxon_counts(elastic_params,
      limit: limit, count_users: @total)

    # # the list of top users is probably different for obs and taxa, so grab the leftovers from each
    obs_user_ids = @user_counts.map{|r| r['user_id']}.sort
    tax_user_ids = @user_taxon_counts.map{|r| r['user_id']}.sort
    leftover_obs_user_ids = tax_user_ids - obs_user_ids
    leftover_tax_user_ids = obs_user_ids - tax_user_ids
    leftover_obs_user_elastic_params = elastic_params.marshal_copy
    leftover_obs_user_elastic_params[:filters] << { terms: { "user.id": leftover_obs_user_ids } }
    leftover_tax_user_elastic_params = elastic_params.marshal_copy
    leftover_tax_user_elastic_params[:filters] << { terms: { "user.id": leftover_tax_user_ids } }
    @user_counts        += Observation.elastic_user_observation_counts(leftover_obs_user_elastic_params)[:counts].to_a
    @user_taxon_counts  += Observation.elastic_user_taxon_counts(leftover_tax_user_elastic_params,
      count_users: leftover_tax_user_ids.length).to_a
    # don't want to return more than were asked for
    @user_counts = @user_counts[0...limit]
    @user_taxon_counts = @user_taxon_counts[0...limit]
  end

  def prepare_counts_elastic_query(search_params)
    elastic_params = Observation.params_to_elastic_query(
      search_params, current_user: current_user).
      select{ |k,v| [ :where, :filters ].include?(k) }
    elastic_params[:filters] ||= [ ]
    elastic_params
  end

  def search_cache_key(search_params)
    search_cache_params = search_params.reject{|k,v|
      %w(controller action format partial).include?(k.to_s)}
    # models to IDs - classes are inconsistently represented as strings
    search_cache_params.each{ |k,v|
      search_cache_params[k] = ElasticModel.id_or_object(v) }
    search_cache_params[:locale] ||= I18n.locale
    search_cache_params[:per_page] ||= search_params[:per_page]
    search_cache_params[:site_id] ||= @site.id
    search_cache_params[:bounds] ||= @site.bounds.to_h if @site.bounds
    "obs_index_#{Digest::MD5.hexdigest(search_cache_params.sort.to_s)}"
  end

  def prepare_map_params(search_params = {})
    map_params = valid_map_params(search_params)
    non_viewer_params = map_params.reject{ |k,v| k == :viewer }
    if @display_map_tiles
      if non_viewer_params.empty?
        # there are no options, so show all observations by default
        @enable_show_all_layer = true
      elsif non_viewer_params.length == 1 && map_params[:taxon]
        # there is just a taxon, so show the taxon observations lyers
        @map_params = { taxon_layers: [ { taxon: map_params[:taxon],
          observations: true, ranges: { disabled: true }, places: { disabled: true },
          gbif: { disabled: true } } ], focus: :observations }
      else
        # otherwise show our catch-all "Featured Observations" custom layer
        map_params[:viewer_id] = current_user.id if logged_in?
        @map_params = { observation_layers: [ map_params.merge(observations: @observations) ] }
      end
    end
  end

  def prepare_map( search_params )
    @display_map_tiles = true
    prepare_map_params(search_params)
  end

  def valid_map_params(search_params = {})
    # make sure we have the params as processed by Observation.query_params
    map_params = (search_params && search_params[:_query_params_set]) ?
      search_params.clone : Observation.query_params(params)
    map_params = map_params.map{ |k,v|
      if v.is_a?(Array)
        [ k, v.map{ |vv| ElasticModel.id_or_object(vv) } ]
      else
        [ k, ElasticModel.id_or_object(v) ]
      end
    }.to_h
    if map_params[:observations_taxon]
      map_params[:taxon_id] = map_params.delete(:observations_taxon)
    end
    if map_params[:projects]
      map_params[:project_ids] = map_params.delete(:projects)
    end
    if map_params[:user]
      map_params[:user_id] = map_params.delete(:user)
    end
    map_params[:precision_offset] = params[:precision_offset]
    map_params.select do |k,v|
      ! [ :utf8, :controller, :action, :page, :per_page,
          :preferences, :color, :_query_params_set,
          :order_by, :order ].include?( k.to_sym )
    end.compact
  end

  def decide_if_skipping_preloading
    @skipping_preloading =
      ( params[:partial] == "cached_component" ) ||
      ( action_name == "taxon_summary" ) ||
      ( action_name == "observation_links" ) ||
      ( action_name == "show" ) ||
      ( action_name == "review" )
  end

  def observations_index_search(params)
    # making `page` default to a string because HTTP params are
    # usually strings and we want to keep the cache_key consistent
    params[:page] ||= "1"
    search_params = Observation.get_search_params(params,
      current_user: current_user, site: @site)
    search_params = Observation.apply_pagination_options(search_params,
      user_preferences: @prefs)
    search_params[:track_total_hits] = true
    if perform_caching && search_params[:q].blank? && (!logged_in? || search_params[:page].to_i == 1)
      search_key = search_cache_key(search_params)
      # Get the cached filtered observations
      observations = Rails.cache.fetch(search_key, expires_in: 5.minutes, compress: true) do
        obs = Observation.page_of_results( search_params, track_total_hits: true )
        # this is doing preloading, as is some code below, but this isn't
        # entirely redundant. If we preload now we can cache the preloaded
        # data to save extra time later on.
        Observation.preload_for_component(obs, logged_in: !!current_user)
        obs
      end
    else
      observations = Observation.page_of_results( search_params, track_total_hits: true )
    end
    set_up_instance_variables(search_params)
    { params: params,
      search_params: search_params,
      observations: observations }
  end

  def ensure_photos_are_local_photos( photos )
    photos.map { |photo|
      if photo.is_a?( LocalPhoto )
        photo
      elsif photo.new_record?
        Photo.local_photo_from_remote_photo( photo )
      else
        Photo.turn_remote_photo_into_local_photo( photo )
        Photo.find_by_id( photo.id ) # || photo.becomes( LocalPhoto ) # ensure we have an object loaded with the right class
      end
    }.compact.uniq
  end

  def ensure_sounds_are_local_sounds( sounds )
    sounds.map { |sound|
      local_sound = if sound.is_a?( LocalSound )
        sound
      elsif sound.new_record?
        local_sound = sound.to_local_sound
      else
        local_sound = sound.to_local_sound!
      end
      local_sound.valid? ? local_sound : sound
    }.compact
  end

end
