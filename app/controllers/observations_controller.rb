#encoding: utf-8
class ObservationsController < ApplicationController
  skip_before_action :verify_authenticity_token, only: :index, if: :json_request?
  protect_from_forgery unless: -> { request.format.widget? } #, except: [:stats, :user_stags, :taxa]
  before_filter :decide_if_skipping_preloading, only: [ :index, :show, :taxon_summary ]
  before_filter :allow_external_iframes, only: [:stats, :user_stats, :taxa, :map]
  before_filter :allow_cors, only: [:index], 'if': -> { Rails.env.development? }

  WIDGET_CACHE_EXPIRATION = 15.minutes
  caches_action :of,
    :expires_in => 1.day,
    :cache_path => Proc.new {|c| c.params.merge(:locale => I18n.locale)},
    :if => Proc.new {|c| c.request.format != :html }
  cache_sweeper :observation_sweeper, :only => [:create, :update, :destroy]
  
  rescue_from ::AbstractController::ActionNotFound  do
    unless @selected_user = User.find_by_login(params[:action])
      return render_404
    end
    by_login
  end

  before_action :doorkeeper_authorize!,
    only: [ :create, :update, :destroy, :viewed_updates, :update_fields, :review ],
    if: lambda { authenticate_with_oauth? }
  
  before_filter :load_user_by_login, :only => [:by_login, :by_login_all]
  after_filter :return_here, :only => [:index, :by_login, :show, 
    :import, :export, :add_from_list, :new, :project]
  before_filter :authenticate_user!,
                :unless => lambda { authenticated_with_oauth? },
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
                            :torquemap]
  load_only = [ :show, :edit, :edit_photos, :update_photos, :destroy,
    :fields, :viewed_updates, :community_taxon_summary, :update_fields,
    :review, :taxon_summary, :observation_links ]
  before_filter :load_observation, :only => load_only
  blocks_spam :only => load_only - [ :taxon_summary, :observation_links ],
    :instance => :observation
  before_filter :require_owner, :only => [:edit, :edit_photos,
    :update_photos, :destroy]
  before_filter :curator_required, :only => [:curation, :accumulation, :phylogram]
  before_filter :load_photo_identities, :only => [:new, :new_batch, :show,
    :new_batch_csv,:edit, :update, :edit_batch, :create, :import, 
    :import_photos, :import_sounds, :new_from_list]
  before_filter :load_sound_identities, :only => [:new, :new_batch, :show,
    :new_batch_csv,:edit, :update, :edit_batch, :create, :import, 
    :import_photos, :import_sounds, :new_from_list]
  before_filter :photo_identities_required, :only => [:import_photos]
  after_filter :refresh_lists_for_batch, :only => [:create, :update]
  before_filter :load_prefs, :only => [:index, :project, :by_login]
  
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
    # the new default /observations doesn't need any observations
    # looked up now as it will use Angular/Node. This is for legacy
    # API methods, and HTML/views and partials
    if request.format.html? && !showing_partial
      params = params
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
          render :js => render_to_string(:partial => "widget.html.erb", :locals => {
            :show_user => true, :target => params[:target], :default_image => params[:default_image], :silence => params[:silence]
          })
        else
          render :js => render_to_string(:partial => "widget.js.erb", :locals => {
            :show_user => true
          })
        end
      end
    end
  end
  
  def of
    if request.format == :html
      redirect_to observations_path(:taxon_id => params[:id])
      return
    end
    unless @taxon = Taxon.find_by_id(params[:id].to_i)
      render_404 && return
    end
    @observations = Observation.of(@taxon).
      includes([ :user,
                    :iconic_taxon,
                    { :taxon => :taxon_descriptions },
                    { :observation_photos => :photo } ]).
      order("observations.id desc").
      limit(500).sort_by{|o| [o.quality_grade == "research" ? 1 : 0, o.id]}
    respond_to do |format|
      format.json do
        render :json => @observations.to_json(
          :methods => [ :user_login, :iconic_taxon_name, :obs_image_url],
          :include => [ { :user => { :only => :login } },
                        :taxon, :iconic_taxon ] )
        end
      format.geojson do
        render :json => @observations.to_geojson(:except => [
          :geom, :latitude, :longitude, :map_scale, 
          :num_identification_agreements, :num_identification_disagreements, 
          :delta, :location_is_exact])
      end
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
          order("establishment_means IN ('endemic', 'introduced') DESC, places.bbox_area ASC").
          first
        @conservation_status = ConservationStatus.
          where( taxon_id: taxon ).where("place_id IN (?)", @places).
          where("iucn >= ?", Taxon::IUCN_NEAR_THREATENED).
          includes(:place).first
      end
      @conservation_status ||= ConservationStatus.where( taxon_id: taxon ).
        where("place_id IS NULL").where("iucn >= ?", Taxon::IUCN_NEAR_THREATENED).first
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
      wikipedia_summary: taxon ? taxon.wikipedia_summary : nil
    }
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
        @project_invitations = @observation.project_invitations.limit(100).to_a
        @project_invitations_by_project_id = @project_invitations.index_by(&:project_id)
      end
      @coordinates_viewable = @observation.coordinates_viewable_by?(current_user)
    end
    respond_to do |format|
      format.html do
        if params[:partial] == "cached_component"
          return render(partial: "cached_component",
            object: @observation, layout: false)
        end
        
        user_viewed_updates(delay: true) if logged_in?
        @observer_provider_authorizations = @observation.user.provider_authorizations
        @shareable_image_url = if !@observation.photos.blank? && photo = @observation.photos.detect{ |p| p.medium_url =~ /^http/ }
          FakeView.image_url( photo.best_url(:original) )
        else
          FakeView.iconic_taxon_image_url( @observation.taxon, size: 200 )
        end
        @shareable_title = if @observation.taxon
          if comname = FakeView.common_taxon_name( @observation.taxon, user: current_user, site: @site ).try(:name)
            "#{comname} (#{@observation.taxon.name})"
          else
            @observation.taxon.name
          end
        else
          I18n.t( "something" )
        end
        @shareable_description = @observation.to_plain_s( no_place_guess: !@coordinates_viewable )
        @shareable_description += ".\n\n#{@observation.description}" unless @observation.description.blank?

        @skip_application_js = true
        @flash_js = true
        return render layout: "bootstrap", action: "show2"
      end
       
      format.xml { render :xml => @observation }
      
      format.json do
        taxon_options = Taxon.default_json_options
        taxon_options[:methods] += [:iconic_taxon_name, :image_url, :common_name, :default_name]
        render :json => @observation.to_json(
          :viewer => current_user,
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
                  :methods => [:license_code, :attribution],
                  :except => [:original_url, :file_processing, :file_file_size, 
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
    @observation.time_zone = current_user.time_zone

    if params[:copy] && (copy_obs = Observation.find_by_id(params[:copy])) && copy_obs.user_id == current_user.id
      %w(observed_on_string time_zone place_guess geoprivacy map_scale positional_accuracy).each do |a|
        @observation.send("#{a}=", copy_obs.send(a))
      end
      @observation.latitude = copy_obs.private_latitude || copy_obs.latitude
      @observation.longitude = copy_obs.private_longitude || copy_obs.longitude
      copy_obs.observation_photos.each do |op|
        @observation.observation_photos.build(:photo => op.photo)
      end
      copy_obs.observation_field_values.each do |ofv|
        @observation.observation_field_values.build(:observation_field => ofv.observation_field, :value => ofv.value)
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
    
    if params[:facebook_photo_id]
      begin
        sync_facebook_photo
      rescue Koala::Facebook::APIError => e
        raise e unless e.message =~ /OAuthException/
        redirect_to ProviderAuthorization::AUTH_URLS['facebook']
        return
      end
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
        @taxon.common_name.name
      else 
        @taxon.name
      end
    elsif !params[:taxon_name].blank?
      @observation.species_guess =  params[:taxon_name]
    end
    
    @observation_fields = ObservationField.recently_used_by(current_user).limit(10)
    
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
    
    if params[:facebook_photo_id]
      begin
        sync_facebook_photo
      rescue Koala::Facebook::APIError => e
        raise e unless e.message =~ /OAuthException/
        redirect_to ProviderAuthorization::AUTH_URLS['facebook']
        return
      end
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
    
    @observations = params[:observations].map do |fieldset_index, observation|
      next if observation.blank?
      observation.delete('fieldset_index') if observation[:fieldset_index]
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

      # Get photos
      photos = []
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
      new_sounds = Sound.from_observation_params(params, fieldset_index, current_user)
      o.sounds << ensure_sounds_are_local_sounds( new_sounds )
      # make sure the obs get a valid observed_on, needed to determine research grade
      o.munge_observed_on_with_chronic
      o.set_quality_grade
      o
    end
    
    @observations.compact.each do |o|
      o.user = current_user
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
            redirect_to :action => self.current_user.login
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
          Observation.refresh_es_index
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

    @observations = Observation.where(id: params[:observations].map{ |k,v| k },
      user_id: observation_user)
    
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
          render :status => :unprocessable_entity, :json => {:error => msg}
        end
      end
      return
    end
    
    # Convert the params to a hash keyed by ID.  Yes, it's weird
    hashed_params = Hash[*params[:observations].to_a.flatten]
    errors = false
    extra_msg = nil
    @observations.each_with_index do |observation,i|
      fieldset_index = observation.id.to_s
      
      # Update the flickr photos
      # Note: this ignore photos thing is a total hack and should only be
      # included if you are updating observations but aren't including flickr
      # fields, e.g. when removing something from ID please
      if !params[:ignore_photos] && !is_mobile_app?
        # Get photos
        updated_photos = []
        old_photo_ids = observation.photo_ids
        Photo.subclasses.each do |klass|
          klass_key = klass.to_s.underscore.pluralize.to_sym
          next if klass_key.blank?
          if params[klass_key] && params[klass_key][fieldset_index]
            updated_photos += retrieve_photos(params[klass_key][fieldset_index], 
              :user => current_user, :photo_class => klass, :sync => true)
          end
        end
        
        if updated_photos.empty?
          observation.photos.clear
        else
          observation.photos = ensure_photos_are_local_photos( updated_photos )
        end

        Photo.subclasses.each do |klass|
          klass_key = klass.to_s.underscore.pluralize.to_sym
          next unless params["#{klass_key}_to_sync"] && params["#{klass_key}_to_sync"][fieldset_index]
          next unless photo = observation.photos.last
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
      
      unless observation.update_attributes(observation_params(hashed_params[observation.id.to_s]))
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
          Observation.refresh_es_index
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
    @observation_photos = ObservationPhoto.where(id: params[:observation_photos].map{|k,v| k})
    @observation_photos.each do |op|
      next unless @observation.observation_photo_ids.include?(op.id)
      op.update_attributes(params[:observation_photos][op.id.to_s])
    end
    
    flash[:notice] = t(:photos_updated)
    redirect_to edit_observation_path(@observation)
  end
  
  # DELETE /observations/1
  # DELETE /observations/1.xml
  def destroy
    @observation.destroy
    respond_to do |format|
      format.html do
        flash[:notice] = t(:observation_was_deleted)
        redirect_to(observations_by_login_path(current_user.login))
      end
      format.xml  { head :ok }
      format.json do
        Observation.refresh_es_index
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
      unique_hash: unique_hash
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
      includes(:quality_metrics, {:observation_photos => :photo}, :taxon)
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
      format.js { render :text => "Observations deleted.", :status => 200 }
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
      @projects = current_user.project_users.joins(:project).includes(:project).order('lower(projects.title)').collect(&:project)
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
      if @flow_task = ObservationsExportFlowTask.find_by_id(params[:flow_task_id])
        output = @flow_task.outputs.first
        @export_url = output ? FakeView.uri_join(root_url, output.file.url).to_s : nil
      end
    end
    @recent_exports = ObservationsExportFlowTask.
      where(user_id: current_user).order(id: :desc).limit(20)
    @observation_fields = ObservationField.recently_used_by(current_user).limit(50).sort_by{|of| of.name.downcase}
    set_up_instance_variables(Observation.get_search_params(params, current_user: current_user, site: @site))
    @identification_fields = if @ident_user
      %w(taxon_id taxon_name taxon_rank category).map{|a| "ident_by_#{@ident_user.login}:#{a}"}
    end
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
    params.update(:user_id => @selected_user.id,
      :viewer => current_user, 
      :filter_spam => (current_user.blank? || current_user != @selected_user)
    )
    search_params = Observation.get_search_params(params,
      current_user: current_user)
    search_params = Observation.apply_pagination_options(search_params,
      user_preferences: @prefs)
    @observations = Observation.page_of_results(search_params)
    set_up_instance_variables(search_params)
    Observation.preload_for_component(@observations, logged_in: !!current_user)
    respond_to do |format|
      format.html do
        determine_if_map_should_be_shown(search_params)
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
          render :js => render_to_string(:partial => "widget.html.erb", :locals => {
            :show_user => false, :target => params[:target], :default_image => params[:default_image], :silence => params[:silence]
          })
        else
          render :js => render_to_string(:partial => "widget.js.erb")
        end
      end
      
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
      project_observations_url(@project.id, url_params)
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
    @project_observations_by_observation_id = @project_observations.index_by(&:observation_id)
    
    @kml_assets = @project.project_assets.select{|pa| pa.asset_file_name =~ /\.km[lz]$/}
    
    respond_to do |format|
      format.html do
        determine_if_map_should_be_shown(search_params)
        if (partial = params[:partial]) && PARTIALS.include?(partial)
          return render_observations_partial(partial)
        end
      end
      format.json do
        render_observations_to_json
      end
      format.atom do
        @updated_at = Observation.last.updated_at
        render :action => "index"
      end
      format.csv do
        pagination_headers_for(@observations)
        render :text => ProjectObservation.to_csv(@project_observations, :user => current_user)
      end
      format.kml do
        render_observations_to_kml(
          :snippet => "#{@project.title.html_safe} Observations", 
          :description => "Observations feed for the #{@site.name} project '#{@project.title.html_safe}'",
          :name => "#{@project.title.html_safe} Observations"
        )
      end
      format.widget do
        if params[:markup_only] == 'true'
          render :js => render_to_string(:partial => "widget.html.erb", :locals => {
            :show_user => true, 
            :target => params[:target], 
            :default_image => params[:default_image], 
            :silence => params[:silence]
          })
        else
          render :js => render_to_string(:partial => "widget.js.erb", :locals => {
            :show_user => true
          })
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
        @observation.places.try(:reverse)
      else
        @observation.public_places.try(:reverse)
      end
      if @observation.taxon && @observation.taxon.species_or_lower?
        @taxon ||= @observation.taxon.genus
      else
        @taxon ||= @observation.taxon
      end
      if @taxon && @places
        @place = @places.reverse.detect {|p| p.taxa.self_and_descendants_of(@taxon).exists?}
      end
    end
    @place ||= (Place.find(params[:place_id]) rescue nil) || @places.try(:last)
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
          render :status => 401, :json => {:error => msg}
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
      ofv_attrs[k][:updater_user_id] = current_user.id
    end
    o = { :observation_field_values_attributes =>  ofv_attrs}
    respond_to do |format|
      if @observation.update_attributes(o)
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
    search_params = Observation.get_search_params(params,
      current_user: current_user)
    if stats_adequately_scoped?(search_params)
      if Observation.able_to_use_elasticsearch?(search_params)
        if params[:rank] == "leaves"
          search_params.delete(:rank)
        end
        elastic_params = prepare_counts_elastic_query(search_params)
        # using 0 for the aggregation count to get all results
        distinct_taxa = Observation.elastic_search(elastic_params.merge(size: 0,
          aggregate: { species: { "taxon.id": 120000 } })).response.aggregations
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
      else
        oscope = Observation.query(search_params)
        if params[:rank] == "leaves" && can_view_leaves
          ancestor_ids_sql = <<-SQL
            SELECT DISTINCT regexp_split_to_table(ancestry, '/') AS ancestor_id
            FROM taxa
              JOIN (
                #{oscope.to_sql}
              ) AS observations ON observations.taxon_id = taxa.id
          SQL
          sql = <<-SQL
            SELECT DISTINCT ON (taxa.id) taxa.*
            FROM taxa
              LEFT OUTER JOIN (
                #{ancestor_ids_sql}
              ) AS ancestor_ids ON taxa.id::text = ancestor_ids.ancestor_id
              JOIN (
                #{oscope.to_sql}
              ) AS observations ON observations.taxon_id = taxa.id
            WHERE ancestor_ids.ancestor_id IS NULL
          SQL
          @taxa = Taxon.find_by_sql(sql)
        else
          @taxa = Taxon.find_by_sql("SELECT DISTINCT ON (taxa.id) taxa.* from taxa INNER JOIN (#{oscope.to_sql}) as o ON o.taxon_id = taxa.id")
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
        ancestor_ids = @taxa.map{|t| t.ancestor_ids[1..-1]}.flatten.uniq
        ancestors = Taxon.where(id: ancestor_ids)
        taxa_to_arrange = (ancestors + @taxa).sort_by{|t| "#{t.ancestry}/#{t.id}"}
        @arranged_taxa = Taxon.arrange_nodes(taxa_to_arrange)
        @taxon_names_by_taxon_id = TaxonName.
          where(taxon_id: taxa_to_arrange.map(&:id).uniq).
          includes(:place_taxon_names).
          group_by(&:taxon_id)
        render :layout => "bootstrap"
      end
      format.csv do
        Taxon.preload_associations(@taxa, [
          :ancestor_taxa, { taxon_names: :place_taxon_names }])
        render :text => @taxa.to_csv(
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
      if Observation.able_to_use_elasticsearch?(search_params)
        elastic_taxon_stats(search_params)
      else
        non_elastic_taxon_stats(search_params)
      end
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
      if Observation.able_to_use_elasticsearch?(search_params)
        elastic_user_stats(search_params, limit)
      else
        non_elastic_user_stats(search_params, limit)
      end
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

  def moimport
    if @api_key = params[:api_key]
      @mo_import_task = MushroomObserverImportFlowTask.new
      @mo_user_id = @mo_import_task.mo_user_id( @api_key )
      @mo_user_name = @mo_import_task.mo_user_name( @api_key )
      @results = @mo_import_task.get_results_xml( api_key: @api_key ).map{ |r| [r, @mo_import_task.observation_from_result( r, skip_images: true )] }
    end
    respond_to do |format|
      format.html { render layout: "bootstrap" }
    end
  end

  def torquemap
    @params = params.except(:controller, :action)
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

  def accumulation
    params[:order_by] = "observed_on"
    params[:order] = "asc"
    search_params = Observation.get_search_params(params,
      current_user: current_user)
    set_up_instance_variables(search_params)
    scope = Observation.query(search_params)
    scope = scope.where("1 = 2") unless stats_adequately_scoped?(search_params)
    scope = scope.joins(:taxon).
      select("observations.id, observations.user_id, observations.created_at, observations.observed_on, observations.time_observed_at, observations.time_zone, taxa.ancestry, taxon_id").
      where("time_observed_at IS NOT NULL")
    rows = ActiveRecord::Base.connection.execute(scope.to_sql)
    row = rows.first
    @observations = rows.map do |row|
      {
        :id => row['id'].to_i,
        :user_id => row['user_id'].to_i,
        :created_at => DateTime.parse(row['created_at']),
        :observed_on => row['observed_on'] ? Date.parse(row['observed_on']) : nil,
        :time_observed_at => row['time_observed_at'] ? DateTime.parse(row['time_observed_at']).in_time_zone(row['time_zone']) : nil,
        :offset_hours => DateTime.parse(row['time_observed_at']).in_time_zone(row['time_zone']).utc_offset / 60 / 60,
        :ancestry => row['ancestry'],
        :taxon_id => row['taxon_id'] ? row['taxon_id'].to_i : nil
      }
    end
    respond_to do |format|
      format.html do
        @headless = true
        render :layout => "bootstrap"
      end
      format.json do
        render :json => {
          :observations => @observations
        }
      end
    end
  end

  def phylogram
    params[:skip_order] = true
    search_params = Observation.get_search_params(params,
      current_user: current_user)
    scope = Observation.query(search_params)
    scope = scope.where("1 = 2") unless stats_adequately_scoped?(search_params)
    ancestor_ids_sql = <<-SQL
      SELECT DISTINCT regexp_split_to_table(ancestry, '/') AS ancestor_id
      FROM taxa
        JOIN (
          #{scope.to_sql}
        ) AS observations ON observations.taxon_id = taxa.id
    SQL
    sql = <<-SQL
      SELECT taxa.id, name, ancestry
      FROM taxa
        LEFT OUTER JOIN (
          #{ancestor_ids_sql}
        ) AS ancestor_ids ON taxa.id::text = ancestor_ids.ancestor_id
        JOIN (
          #{scope.to_sql}
        ) AS observations ON observations.taxon_id = taxa.id
      WHERE ancestor_ids.ancestor_id IS NULL
    SQL
    @taxa = ActiveRecord::Base.connection.execute(sql)
    respond_to do |format|
      format.html do
        @headless = true
        render :layout => "bootstrap"
      end
      format.json do
        render :json => {
          :taxa => @taxa
        }
      end
    end
  end

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
        Observation.refresh_es_index
        head :no_content
      end
    end
  end

  def email_export
    unless flow_task = current_user.flow_tasks.find_by_id(params[:id])
      render status: :unprocessable_entity, text: "Flow task doesn't exist"
      return
    end
    if flow_task.user_id != current_user.id
      render status: :unprocessable_entity, text: "You don't have permission to do that"
      return
    end
    if flow_task.outputs.exists?
      Emailer.observations_export_notification(flow_task).deliver_now
      render status: :ok, text: ""
      return
    elsif flow_task.error
      Emailer.observations_export_failed_notification(flow_task).deliver_now
      render status: :ok, text: ""
      return
    end
    flow_task.options = flow_task.options.merge(:email => true)
    if flow_task.save
      render status: :ok, text: ""
    else
      render status: :unprocessable_entity, text: flow_task.errors.full_messages.to_sentence
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
      common_name = view_context.common_taxon_name(@taxon).try(:name)
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
                    params[:color] != "heatmap" ) ? "colored_heatmap" : "heatmap"
    @map_type = ( params[:type] == "map" ) ? "MAP" : "SATELLITE"
    @default_color = params[:heatmap_colors] if @map_style == "heatmap"
    @about_url = @site.map_about_url ? @site.map_about_url :
      view_context.wiki_page_url('help', anchor: 'mapsymbols')
  end

  def observation_links
    render json: @observation.observation_links
  end

## Protected / private actions ###############################################
  private

  def user_viewed_updates(options={})
    return unless logged_in?
    if options[:delay]
      @observation.delay(priority: USER_PRIORITY).user_viewed_updates(current_user.id)
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
    review.update_attributes({ user_added: true, reviewed: reviewed })
    review.observation.elastic_index!
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
    existing = (LocalPhoto.where(subtype: photo_class, native_photo_id: native_photo_ids) +
      photo_class.includes(:user).where(native_photo_id: native_photo_ids)).
      index_by{|p| p.native_photo_id }
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
          if photo_id.is_a?(Fixnum) || photo_id.is_a?(String)
            LocalPhoto.find_by_id(photo_id)
          else
            LocalPhoto.new(:file => photo_id, :user => current_user) unless photo_id.blank?
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
    @q = search_params[:q] unless search_params[:q].blank?
    @search_on = search_params[:search_on]
    @iconic_taxa = search_params[:iconic_taxa_instances]
    @observations_taxon_id = search_params[:observations_taxon_id]
    @observations_taxon = search_params[:observations_taxon]
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
    @out_of_range = search_params[:out_of_range]
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
    @rank = search_params[:rank]
    @hrank = search_params[:hrank]
    @lrank = search_params[:lrank]
    @verifiable = search_params[:verifiable]
    @threatened = search_params[:threatened]
    @introduced = search_params[:introduced]
    @popular = search_params[:popular]
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
    
    @filters_open = 
      !@q.nil? ||
      !@observations_taxon_id.blank? ||
      !@observations_taxon_name.blank? ||
      !@iconic_taxa.blank? ||
      @id_please == true ||
      !@with_photos.blank? ||
      !@with_sounds.blank? ||
      !@identifications.blank? ||
      !@quality_grade.blank? ||
      !@captive.blank? ||
      !@out_of_range.blank? ||
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

  # Refresh lists affected by taxon changes in a batch of new/edited
  # observations.  Note that if you don't set @skip_refresh_lists on the records
  # in @observations before this is called, this won't do anything
  def refresh_lists_for_batch
    return true if @observations.blank?
    taxa = @observations.to_a.compact.select(&:skip_refresh_lists).map(&:taxon).uniq.compact
    return true if taxa.blank?
    List.delay(:priority => USER_PRIORITY).refresh_for_user(current_user, :taxa => taxa.map(&:id))
    true
  end
  
  # Tries to create a new observation from the specified Facebook photo ID and
  # update the existing @observation with the new properties, without saving
  def sync_facebook_photo
    fb = current_user.facebook_api
    if fb
      fbp_json = FacebookPhoto.get_api_response(params[:facebook_photo_id], :user => current_user)
      @facebook_photo = FacebookPhoto.new_from_api_response(fbp_json)
    else 
      @facebook_photo = nil
    end
    if @facebook_photo && @facebook_photo.owned_by?(current_user)
      @facebook_observation = @facebook_photo.to_observation
      sync_attrs = [:description] # facebook strips exif metadata so we can't get geo or observed_on :-/
      #, :species_guess, :taxon_id, :observed_on, :observed_on_string, :latitude, :longitude, :place_guess]
      unless params[:facebook_sync_attrs].blank?
        sync_attrs = sync_attrs & params[:facebook_sync_attrs]
      end
      sync_attrs.each do |sync_attr|
        # merge facebook_observation with existing observation
        @observation[sync_attr] ||= @facebook_observation[sync_attr]
      end
      unless @observation.observation_photos.detect {|op| op.photo.native_photo_id == @facebook_photo.native_photo_id}
        @observation.observation_photos.build(:photo => @facebook_photo)
      end
      unless @observation.new_record?
        flash.now[:notice] = t(:preview_of_synced_observation, :url => url_for)
      end
    else
      flash.now[:error] = t(:sorry_we_didnt_find_that_photo)
    end
  end

  # Tries to create a new observation from the specified Flickr photo ID and
  # update the existing @observation with the new properties, without saving
  def sync_flickr_photo
    flickr = get_flickraw
    begin
      fp = flickr.photos.getInfo(:photo_id => params[:flickr_photo_id])
      @flickr_photo = FlickrPhoto.new_from_flickraw(fp, :user => current_user)
    rescue FlickRaw::FailedResponse => e
      Rails.logger.debug "[DEBUG] FlickRaw failed to find photo " +
        "#{params[:flickr_photo_id]}: #{e}\n#{e.backtrace.join("\n")}"
      @flickr_photo = nil
    rescue Timeout::Error => e
      flash.now[:error] = t(:sorry_flickr_isnt_responding_at_the_moment)
      Rails.logger.error "[ERROR #{Time.now}] Timeout: #{e}"
      Airbrake.notify(e, :request => request, :session => session)
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
      unless @observation.observation_photos.detect {|op| op.photo.native_photo_id == @flickr_photo.native_photo_id}
        @observation.observation_photos.build(:photo => @flickr_photo)
      end
      
      unless @observation.new_record?
        flash.now[:notice] = t(:preview_of_synced_observation, :url => url_for)
      end
      
      if (@existing_photo = Photo.find_by_native_photo_id(@flickr_photo.native_photo_id)) && 
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
      Airbrake.notify(e, :request => request, :session => session)
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
      
      unless @observation.observation_photos.detect {|op| op.photo.native_photo_id == @picasa_photo.native_photo_id}
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
    
    if @existing_photo_observation = @local_photo.observations.where("observations.id != ?", @observation).first
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
      FacebookPhoto
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
    if params[:facebook_photo_id]
      if @default_photo_identity = @photo_identities.detect{|pi| pi.to_s =~ /facebook/i}
        @default_photo_source = 'facebook'
      end
    elsif params[:flickr_photo_id]
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
        if ident.provider_name == "facebook"
          memo[:facebook] = {
            :title => 'Facebook', 
            :url => '/facebook/photo_fields', 
            :contexts => [
              ["Your photos", 'user']
            ]
          }
        elsif ident.provider_name =~ /google/
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
    scope = Observation.where(id: params[:id] || params[:observation_id])
    includes = [ :quality_metrics,
      :flags,
      { photos: :flags },
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
  
  def require_owner
    unless logged_in? && current_user.id == @observation.user_id
      msg = t(:you_dont_have_permission_to_do_that)
      respond_to do |format|
        format.html do
          flash[:error] = msg
          return redirect_to @observation
        end
        format.json do
          return render :json => {:error => msg}
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
      except += %w(private_latitude private_longitude private_positional_accuracy)
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
    render :text => Observation.as_csv(@observations, only.map{|c| c.to_sym},
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
    current_user.update_attributes(params[:user]) unless params[:user].blank?
  end
  
  def render_observations_partial(partial)
    if @observations.empty?
      render(:text => '')
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
    path_for_csv_no_ext = path_for_csv.gsub(/\.csv\z/, '')
    if parent.observations.count < 50
      Observation.generate_csv_for(parent, :path => path_for_csv, :user => current_user)
      render :file => path_for_csv_no_ext, :formats => [:csv]
    else
      cache_key = Observation.generate_csv_for_cache_key(parent)
      job_id = Rails.cache.read(cache_key)
      job = Delayed::Job.find_by_id(job_id)
      if job
        # Still working
      elsif File.exists? path_for_csv
        render :file => path_for_csv_no_ext, :formats => [:csv]
        return
      else
        # no job id, no job, let's get this party started
        Rails.cache.delete(cache_key)
        job = Observation.delay(:priority => NOTIFICATION_PRIORITY).generate_csv_for(parent, :path => path_for_csv, :user => current_user)
        Rails.cache.write(cache_key, job.id, :expires_in => 1.hour)
      end
      prevent_caching
      render :status => :accepted, :text => "This file takes a little while to generate. It should be ready shortly at #{request.url}"
    end
  end

  def non_elastic_taxon_stats(search_params)
    scope = Observation.query(search_params)
    scope = scope.where("1 = 2") unless stats_adequately_scoped?(search_params)
    species_counts_scope = scope.joins(:taxon)
    unless search_params[:rank] == "leaves" && logged_in? && current_user.is_curator?
      species_counts_scope = species_counts_scope.where("taxa.rank_level <= ?", Taxon::SPECIES_LEVEL)
    end
    species_counts_sql = if search_params[:rank] == "leaves" && logged_in? && current_user.is_curator?
      ancestor_ids_sql = <<-SQL
        SELECT DISTINCT regexp_split_to_table(ancestry, '/') AS ancestor_id
        FROM taxa
          JOIN (
            #{species_counts_scope.to_sql}
          ) AS observations ON observations.taxon_id = taxa.id
      SQL
      <<-SQL
        SELECT
          o.taxon_id,
          count(*) AS count_all
        FROM
          (
            #{species_counts_scope.to_sql}
          ) AS o
            LEFT OUTER JOIN (
              #{ancestor_ids_sql}
            ) AS ancestor_ids ON o.taxon_id::text = ancestor_ids.ancestor_id
        WHERE
          ancestor_ids.ancestor_id IS NULL
        GROUP BY
          o.taxon_id
        ORDER BY count_all desc
        LIMIT 5
      SQL
    else
      <<-SQL
        SELECT
          o.taxon_id,
          count(*) AS count_all
        FROM
          (#{species_counts_scope.to_sql}) AS o
        GROUP BY
          o.taxon_id
        ORDER BY count_all desc
        LIMIT 5
      SQL
    end
    @species_counts = ActiveRecord::Base.connection.execute(species_counts_sql)
    taxon_ids = @species_counts.map{|r| r['taxon_id']}
    rank_counts_sql = <<-SQL
      SELECT
        o.rank_name,
        count(*) AS count_all
      FROM
        (#{scope.joins(:taxon).select("DISTINCT ON (taxa.id) taxa.rank AS rank_name").to_sql}) AS o
      GROUP BY o.rank_name
    SQL
    @raw_rank_counts = ActiveRecord::Base.connection.execute(rank_counts_sql)
    @rank_counts = {}
    @total = 0
    @raw_rank_counts.each do |row|
      @total += row['count_all'].to_i
      @rank_counts[row['rank_name']] = row['count_all'].to_i
    end
    # TODO: we should set a proper value for @rank_counts[:leaves]
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

  def non_elastic_user_stats(search_params, limit)
    scope = Observation.query(search_params)
    scope = scope.where("1 = 2") unless stats_adequately_scoped?(search_params)
    @user_counts = user_obs_counts(scope, limit).to_a
    @user_taxon_counts = user_taxon_counts(scope, limit).to_a
    obs_user_ids = @user_counts.map{|r| r['user_id']}.sort
    tax_user_ids = @user_taxon_counts.map{|r| r['user_id']}.sort

    # the list of top users is probably different for obs and taxa, so grab the leftovers from each
    leftover_obs_user_ids = tax_user_ids - obs_user_ids
    leftover_tax_user_ids = obs_user_ids - tax_user_ids
    @user_counts += user_obs_counts(scope.where("observations.user_id IN (?)", leftover_obs_user_ids)).to_a
    @user_taxon_counts += user_taxon_counts(scope.where("observations.user_id IN (?)", leftover_tax_user_ids)).to_a
    @user_counts = @user_counts[0...limit]
    @user_taxon_counts = @user_taxon_counts[0...limit]
    @total = scope.select("DISTINCT observations.user_id").count
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

  def determine_if_map_should_be_shown( search_params )
    if @display_map_tiles = Observation.able_to_use_elasticsearch?( search_params )
      prepare_map_params(search_params)
    end
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
      ( action_name == "show" )
  end

  def observations_index_search(params)
    # making `page` default to a string because HTTP params are
    # usually strings and we want to keep the cache_key consistent
    params[:page] ||= "1"
    search_params = Observation.get_search_params(params,
      current_user: current_user, site: @site)
    search_params = Observation.apply_pagination_options(search_params,
      user_preferences: @prefs)
    if perform_caching && search_params[:q].blank? && (!logged_in? || search_params[:page].to_i == 1)
      search_key = search_cache_key(search_params)
      # Get the cached filtered observations
      observations = Rails.cache.fetch(search_key, expires_in: 5.minutes, compress: true) do
        obs = Observation.page_of_results(search_params)
        # this is doing preloading, as is some code below, but this isn't
        # entirely redundant. If we preload now we can cache the preloaded
        # data to save extra time later on.
        Observation.preload_for_component(obs, logged_in: !!current_user)
        obs
      end
    else
      observations = Observation.page_of_results(search_params)
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
    }.compact
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
