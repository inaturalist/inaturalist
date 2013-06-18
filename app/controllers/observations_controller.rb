#encoding: utf-8
class ObservationsController < ApplicationController
  caches_page :tile_points
  
  WIDGET_CACHE_EXPIRATION = 15.minutes
  caches_action :index, :by_login, :project,
    :expires_in => WIDGET_CACHE_EXPIRATION,
    :cache_path => Proc.new {|c| c.params.merge(:locale => I18n.locale)},
    :if => Proc.new {|c| 
      c.session.blank? && # make sure they're logged out
      c.request.format && # make sure format corresponds to a known mime type
      (c.request.format.geojson? || c.request.format.widget? || c.request.format.kml?) && 
      c.request.url.size < 250}
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

  doorkeeper_for :create, :update, :destroy, :if => lambda { authenticate_with_oauth? }
  
  before_filter :load_user_by_login, :only => [:by_login, :by_login_all]
  before_filter :return_here, :only => [:index, :by_login, :show, :id_please, 
    :import, :add_from_list, :new, :project]
  before_filter :authenticate_user!,
                :unless => lambda { authenticated_with_oauth? },
                :except => [:explore,
                            :index,
                            :of,
                            :show,
                            :by_login,
                            :id_please,
                            :tile_points,
                            :nearby,
                            :widget,
                            :project]
  before_filter :load_observation, :only => [:show, :edit, :edit_photos, :update_photos, :destroy, :fields]
  before_filter :require_owner, :only => [:edit, :edit_photos,
    :update_photos, :destroy]
  before_filter :curator_required, :only => [:curation]
  before_filter :load_photo_identities, :only => [:new, :new_batch, :show,
    :new_batch_csv,:edit, :update, :edit_batch, :create, :import, 
    :import_photos, :import_sounds, :new_from_list]
  before_filter :load_sound_identities, :only => [:new, :new_batch, :show,
    :new_batch_csv,:edit, :update, :edit_batch, :create, :import, 
    :import_photos, :import_sounds, :new_from_list]
  before_filter :photo_identities_required, :only => [:import_photos]
  after_filter :refresh_lists_for_batch, :only => [:create, :update]
  
  MOBILIZED = [:add_from_list, :nearby, :add_nearby, :project, :by_login, :index, :show]
  before_filter :unmobilized, :except => MOBILIZED
  before_filter :mobilized, :only => MOBILIZED
  before_filter :load_prefs, :only => [:index, :project, :by_login]
  
  ORDER_BY_FIELDS = %w"created_at observed_on species_guess"
  REJECTED_FEED_PARAMS = %w"page view filters_open partial"
  REJECTED_KML_FEED_PARAMS = REJECTED_FEED_PARAMS + %w"swlat swlng nelat nelng"
  DISPLAY_ORDER_BY_FIELDS = {
    'created_at' => 'date added',
    'observations.id' => 'date added',
    'id' => 'date added',
    'observed_on' => 'date observed',
    'species_guess' => 'species name'
  }
  PARTIALS = %w(cached_component observation_component observation mini)
  EDIT_PARTIALS = %w(add_photos)
  PHOTO_SYNC_ATTRS = [:description, :species_guess, :taxon_id, :observed_on,
    :observed_on_string, :latitude, :longitude, :place_guess]

  # GET /observations
  # GET /observations.xml
  def index
    search_params, find_options = get_search_params(params)
    search_params = site_search_params(search_params)
    
    if search_params[:q].blank?
      @observations = if perform_caching
        cache_params = params.reject{|k,v| %w(controller action format partial).include?(k.to_s)}
        cache_params[:page] ||= 1
        cache_params[:site_name] ||= SITE_NAME if CONFIG.site_only_observations
        cache_params[:bounds] ||= CONFIG.bounds if CONFIG.bounds
        cache_key = "obs_index_#{Digest::MD5.hexdigest(cache_params.to_s)}"
        Rails.cache.fetch(cache_key, :expires_in => 5.minutes) do
          get_paginated_observations(search_params, find_options).to_a
        end
      else
        get_paginated_observations(search_params, find_options)
      end
    else
      @observations = search_observations(search_params, find_options)
    end

    respond_to do |format|
      
      format.html do
        @iconic_taxa ||= []
        if (partial = params[:partial]) && PARTIALS.include?(partial)
          pagination_headers_for(@observations)
          return render_observations_partial(partial)
        end
      end

      format.json do
        render_observations_to_json
      end
      
      format.mobile
      
      format.geojson do
        render :json => @observations.to_geojson(:except => [
          :geom, :latitude, :longitude, :map_scale, 
          :num_identification_agreements, :num_identification_disagreements, 
          :delta, :location_is_exact])
      end
      
      format.atom do
        @updated_at = Observation.first(:order => 'updated_at DESC').updated_at
      end
      
      format.dwc

      format.csv do
        render_observations_to_csv
      end
      
      format.kml do
        render_observations_to_kml(
          :snippet => "#{CONFIG.site_name} Feed for Everyone", 
          :description => "#{CONFIG.site_name} Feed for Everyone", 
          :name => "#{CONFIG.site_name} Feed for Everyone"
        )
      end
      
      format.widget do
        if params[:markup_only]=='true'
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
    @observations = Observation.of(@taxon).all(
      :include => [:user, :taxon, :iconic_taxon, :observation_photos => [:photo]], 
      :order => "observations.id desc", 
      :limit => 500).sort_by{|o| [o.quality_grade == "research" ? 1 : 0, o.id]}
    respond_to do |format|
      format.json do
        render :json => @observations.to_json(
          :methods => [:user_login, :iconic_taxon_name, :obs_image_url],
          :include => {:user => {:only => :login}, :taxon => {}, :iconic_taxon => {}})
        end
      format.geojson do
        render :json => @observations.to_geojson(:except => [
          :geom, :latitude, :longitude, :map_scale, 
          :num_identification_agreements, :num_identification_disagreements, 
          :delta, :location_is_exact])
      end
    end
  end
  
  # GET /observations/1
  # GET /observations/1.xml
  def show
    if request.format == :html && 
        params[:partial] == "cached_component" && 
        fragment_exist?(@observation.component_cache_key(:for_owner => @observation.user_id == current_user.try(:id)))
      return render(:partial => params[:partial], :object => @observation,
        :layout => false)
    end
    
    @previous = @observation.user.observations.first(:conditions => ["id < ?", @observation.id], :order => "id DESC")
    @prev = @previous
    @next = @observation.user.observations.first(:conditions => ["id > ?", @observation.id], :order => "id ASC")
    @quality_metrics = @observation.quality_metrics.all(:include => :user)
    if logged_in?
      @user_quality_metrics = @observation.quality_metrics.select{|qm| qm.user_id == current_user.id}
      @project_invitations = @observation.project_invitations.limit(100).to_a
      @project_invitations_by_project_id = @project_invitations.index_by(&:project_id)
    end
    
    respond_to do |format|
      format.html do
        # always display the time in the zone in which is was observed
        Time.zone = @observation.user.time_zone
                
        @identifications = @observation.identifications.includes(:user, :taxon => :photos)
        @current_identifications = @identifications.select{|o| o.current?}
        @owners_identification = @current_identifications.detect do |ident|
          ident.user_id == @observation.user_id
        end
        if logged_in?
          @viewers_identification = @current_identifications.detect do |ident|
            ident.user_id == current_user.id
          end
        end
        
        @current_identifications_by_taxon = @current_identifications.select do |ident|
          ident.user_id != ident.observation.user_id
        end.group_by{|i| i.taxon}
        @current_identifications_by_taxon = @current_identifications_by_taxon.sort_by do |row|
          row.last.size
        end.reverse
        
        if logged_in?
          # Make sure the viewer's ID is first in its group
          @current_identifications_by_taxon.each_with_index do |pair, i|
            if pair.last.map(&:user_id).include?(current_user.id)
              pair.last.delete(@viewers_identification)
              identifications = [@viewers_identification] + pair.last
              @current_identifications_by_taxon[i] = [pair.first, identifications]
            end
          end
          
          @projects = Project.all(
            :joins => [:project_users], 
            :limit => 1000, 
            :conditions => ["project_users.user_id = ?", current_user]
          ).sort_by{|p| p.title.downcase}
        end
        
        @places = @observation.places
        
        @project_observations = @observation.project_observations.limit(100).to_a
        @project_observations_by_project_id = @project_observations.index_by(&:project_id)
        
        @comments_and_identifications = (@observation.comments.all + 
          @identifications).sort_by{|r| r.created_at}
        
        @photos = @observation.observation_photos.sort_by do |op| 
          op.position || @observation.observation_photos.size + op.id.to_i
        end.map{|op| op.photo}
        
        if @observation.observed_on
          @day_observations = Observation.by(@observation.user).on(@observation.observed_on).
            includes(:photos).
            paginate(:page => 1, :per_page => 14)
        end
        
        if logged_in?
          @subscription = @observation.update_subscriptions.first(:conditions => {:user_id => current_user})
        end
        
        @observation_links = @observation.observation_links.sort_by{|ol| ol.href}
        @posts = @observation.posts.published.limit(50)

        if @observation.taxon
          unless @places.blank?
            @listed_taxon = ListedTaxon.
              where("taxon_id = ? AND place_id IN (?) AND establishment_means IS NOT NULL", @observation.taxon_id, @places).
              includes(:place).first
            @conservation_status = ConservationStatus.
              where(:taxon_id => @observation.taxon).where("place_id IN (?)", @places).
              where("iucn >= ?", Taxon::IUCN_NEAR_THREATENED).
              includes(:place).first
          end
          @conservation_status ||= ConservationStatus.where(:taxon_id => @observation.taxon).where("place_id IS NULL").
            where("iucn >= ?", Taxon::IUCN_NEAR_THREATENED).first
        end

        @observer_provider_authorizations = @observation.user.provider_authorizations
        
        if params[:partial]
          return render(:partial => params[:partial], :object => @observation,
            :layout => false)
        end
      end
      
      format.mobile
       
      format.xml { render :xml => @observation }
      
      format.json do
        render :json => @observation.to_json(
          :viewer => current_user,
          :methods => [:user_login, :iconic_taxon_name],
          :include => {
            :observation_field_values => {},
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
    @observation.id_please = params[:id_please]
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
      @taxon ||= TaxonName.first(:conditions => [
        "lower(name) = ?", params[:taxon_name].to_s.strip.gsub(/[\s_]+/, ' ').downcase]
      ).try(:taxon)
    end
    
    if !params[:project_id].blank?
      @project = if params[:project_id].to_i == 0
        Project.includes(:project_observation_fields => :observation_field).find(params[:project_id])
      else
        Project.includes(:project_observation_fields => :observation_field).find_by_id(params[:project_id].to_i)
      end
      if @project
        @project_curators = @project.project_users.where("role IN (?)", [ProjectUser::MANAGER, ProjectUser::CURATOR])
        if @place = @project.place
          @place_geometry = PlaceGeometry.without_geom.first(:conditions => {:place_id => @place})
        end
        @tracking_code = params[:tracking_code] if @project.tracking_code_allowed?(params[:tracking_code])
        @kml_assets = @project.project_assets.select{|pa| pa.asset_file_name =~ /\.km[lz]$/}
      end
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
    
    @observation_fields = ObservationField.
      includes(:observation_field_values => :observation).
      where("observations.user_id = ?", current_user).
      limit(10).
      order("observation_field_values.id DESC")
    
    respond_to do |format|
      format.html do
        @observations = [@observation]
        @sharing_authorizations = current_user.provider_authorizations.select do |pa|
          pa.provider_name == "facebook" || (pa.provider_name == "twitter" && !pa.secret.blank?)
        end
      end
      format.json  { render :json => @observation }
    end
  end
  
  # def quickadd
  #   if params[:txt]
  #     pieces = txt.split(/\sat\s|\son\s|\sin\s/)
  #     @observation = Observation.new(:species_guess => pieces.first)
  #     @observation.place_guess = pieces.last if pieces.size > 1
  #     if pieces.size > 2
  #       @observation.observed_on_string = pieces[1..-2].join(' ')
  #     end
  #     @observation.user = self.current_user
  #   end
  #   respond_to do |format|
  #     if @observation.save
  #       flash[:notice] = "Your observation was saved."
  #       format.html { redirect_to :action => @user.login }
  #       format.xml  { render :xml => @observation, :status => :created, 
  #                            :location => @observation }
  #       format.js   { render }
  #     else
  #       format.html { render :action => "new" }
  #       format.xml  { render :xml => @observation.errors, 
  #                            :status => :unprocessable_entity }
  #       format.js   { render :json => @observation.errors, 
  #                            :status => :unprocessable_entity }
  #     end
  #   end
  # end
  
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
    @observation_fields = ObservationField.
      includes(:observation_field_values => {:observation => :user}).
      where("users.id = ?", current_user).
      limit(10).
      order("observation_field_values.id DESC")

    if @observation.quality_metrics.detect{|qm| qm.user_id == @observation.user_id && qm.metric == QualityMetric::WILD && !qm.agree?}
      @observation.captive = true
    end
    if params[:partial] && EDIT_PARTIALS.include?(params[:partial])
      return render(:partial => params[:partial], :object => @observation,
        :layout => false)
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
          flash[:error] = "No observations submitted!"
          redirect_to new_observation_path
        end
        format.json { render :status => :unprocessable_entity, :json => "No observations submitted!" }
      end
      return
    end
    
    @observations = params[:observations].map do |fieldset_index, observation|
      next unless observation
      observation.delete('fieldset_index') if observation[:fieldset_index]
      o = Observation.new(observation)
      o.user = current_user
      o.user_agent = request.user_agent
      if doorkeeper_token && (a = doorkeeper_token.application)
        o.oauth_application = a.becomes(OauthApplication)
      end
      # Get photos
      Photo.descendent_classes.each do |klass|
        klass_key = klass.to_s.underscore.pluralize.to_sym
        if params[klass_key] && params[klass_key][fieldset_index]
          o.photos << retrieve_photos(params[klass_key][fieldset_index], 
            :user => current_user, :photo_class => klass)
        end
        if params["#{klass_key}_to_sync"] && params["#{klass_key}_to_sync"][fieldset_index]
          if photo = o.photos.compact.last
            photo_o = photo.to_observation
            PHOTO_SYNC_ATTRS.each do |a|
              o.send("#{a}=", photo_o.send(a))
            end
          end
        end
      end
      o.sounds << Sound.from_observation_params(params, fieldset_index, current_user)
      o
    end
    
    current_user.observations << @observations
    
    if request.format != :json && !params[:accept_terms] && params[:project_id] && !current_user.project_users.find_by_project_id(params[:project_id])
      flash[:error] = "But we didn't add this observation to the #{Project.find_by_id(params[:project_id]).title} project because you didn't agree to the project terms."
    else
      create_project_observations
    end
    update_user_account
    
    # check for errors
    errors = false
    @observations.each { |obs| errors = true unless obs.valid? }
    respond_to do |format|
      format.html do
        unless errors
          flash[:notice] = params[:success_msg] || "Observation(s) saved!"
          if params[:commit] == "Save and add another"
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
                :taxon => Taxon.default_json_options,
                :observation_field_values => {}
              }
            )
          else
            render :json => @observations.to_json(:viewer => current_user, :methods => [:user_login, :iconic_taxon_name])
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
          flash[:error] = "No observations submitted!"
          redirect_to new_observation_path
        end
        format.json { render :status => :unprocessable_entity, :json => "No observations submitted!" }
      end
      return
    end

    @observations = Observation.all(
      :conditions => [
        "id IN (?) AND user_id = ?", 
        params[:observations].map{|k,v| k},
        observation_user
      ]
    )
    
    # Make sure there's no evil going on
    unique_user_ids = @observations.map(&:user_id).uniq
    if unique_user_ids.size > 1 || unique_user_ids.first != observation_user.id && !current_user.has_role?(:admin)
      flash[:error] = "You don't have permission to edit that observation."
      return redirect_to(@observation || observations_path)
    end
    
    # Convert the params to a hash keyed by ID.  Yes, it's weird
    hashed_params = Hash[*params[:observations].to_a.flatten]
    errors = false
    extra_msg = nil
    @observations.each do |observation|
      fieldset_index = observation.id.to_s      
      
      # Update the flickr photos
      # Note: this ignore photos thing is a total hack and should only be
      # included if you are updating observations but aren't including flickr
      # fields, e.g. when removing something from ID please
      if !params[:ignore_photos] && !is_mobile_app?
        # Get photos
        updated_photos = []
        old_photo_ids = observation.photo_ids
        Photo.descendent_classes.each do |klass|
          klass_key = klass.to_s.underscore.pluralize.to_sym
          if params[klass_key] && params[klass_key][fieldset_index]
            updated_photos += retrieve_photos(params[klass_key][fieldset_index], 
              :user => current_user, :photo_class => klass, :sync => true)
          end
        end
        
        if updated_photos.empty?
          observation.photos.clear
        else
          observation.photos = updated_photos
        end
        
        # Destroy old photos.  ObservationPhotos seem to get removed by magic
        doomed_photo_ids = (old_photo_ids - observation.photo_ids).compact
        unless doomed_photo_ids.blank?
          Photo.delay.destroy_orphans(doomed_photo_ids)
        end
      end


      # Kind of like :ignore_photos, but :editing_sounds makes it opt-in rather than opt-out
      # If editing sounds and no sound parameters are present, assign to an empty array 
      # This way, sounds will be removed
      if params[:editing_sounds]
        params[:soundcloud_sounds] ||= {fieldset_index => []} 
        params[:soundcloud_sounds][fieldset_index] ||= []
      end
      observation.sounds = Sound.from_observation_params(params, fieldset_index, current_user)

      
      unless observation.update_attributes(hashed_params[observation.id.to_s])
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
          "That observation no longer exists."
        else
          "Those observations no longer exist."
        end
        format.html do
          flash[:error] = msg
          redirect_back_or_default(observations_by_login_path(current_user.login))
        end
        format.json { render :json => {:error => msg}, :status => :gone }
      else
        format.html do
          flash[:notice] = "Observation(s) was successfully updated. #{extra_msg}"
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
              :methods => [:user_login, :iconic_taxon_name],
              :include => {
                :taxon => Taxon.default_json_options,
                :observation_field_values => {},
                :project_observations => {
                  :include => {
                    :project => {
                      :only => [:id, :title, :description],
                      :methods => [:icon_url]
                    }
                  }
                },
                :observation_photos => {
                  :except => [:file_processing, :file_file_size, 
                    :file_content_type, :file_file_name, :user_id, 
                    :native_realname, :mobile, :native_photo_id],
                  :include => {
                    :photo => {}
                  }
                }
              })
          else
            render :json => @observations.to_json(:methods => [:user_login, :iconic_taxon_name])
          end
        end
      end
    end
  end
  
  def edit_photos
    @observation_photos = @observation.observation_photos
    if @observation_photos.blank?
      flash[:error] = "That observation doesn't have any photos."
      return redirect_to edit_observation_path(@observation)
    end
  end
  
  def update_photos
    @observation_photos = ObservationPhoto.all(:conditions => [
      "id IN (?)", params[:observation_photos].map{|k,v| k}])
    @observation_photos.each do |op|
      next unless @observation.observation_photo_ids.include?(op.id)
      op.update_attributes(params[:observation_photos][op.id.to_s])
    end
    
    flash[:notice] = "Photos updated."
    redirect_to edit_observation_path(@observation)
  end
  
  # DELETE /observations/1
  # DELETE /observations/1.xml
  def destroy
    @observation.destroy
    respond_to do |format|
      format.html do
        flash[:notice] = "Observation was deleted."
        redirect_to(observations_by_login_path(current_user.login))
      end
      format.xml  { head :ok }
      format.json  { head :ok }
    end
  end

## Custom actions ############################################################

  def curation
    @flags = Flag.paginate(:page => params[:page], 
      :include => :user,
      :conditions => "resolved = false AND flaggable_type = 'Observation'")
  end

  def new_batch
    @step = 1
    @observations = []
    if params[:batch]
      params[:batch][:taxa].each_line do |taxon_name_str|
        next if taxon_name_str.strip.blank?
        latitude = params[:batch][:latitude]
        longitude = params[:batch][:longitude]
        if latitude.nil? && longitude.nil? && params[:batch][:place_guess]
          places = Ym4r::GmPlugin::Geocoding.get(params[:batch][:place_guess])
          unless places.empty?
            latitude = places.first.latitude
            longitude = places.first.longitude
          end
        end
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


  def new_batch_csv
    if params[:upload].blank? || params[:upload] && params[:upload][:datafile].blank?
      flash[:error] = "You must select a CSV file to upload."
      return redirect_to :action => "import"
    end

    @observations = []
    @hasInvalid = false
    csv = params[:upload][:datafile].read
    max_rows = 100
    row_num = 0
    @rows = []
    
    begin
      CSV.parse(csv) do |row|
        next if row.blank?
        row = row.map do |item|
          if item.blank?
            nil
          else
            begin
              item.to_s.encode('UTF-8').strip
            rescue Encoding::UndefinedConversionError => e
              problem = e.message[/"(.+)" from/, 1]
              begin
                item.to_s.gsub(problem, '').encode('UTF-8').strip
              rescue Encoding::UndefinedConversionError => e
                # If there's more than one encoding issue, just bail
                ''
              end
            end
          end
        end
        obs = Observation.new(
          :user => current_user,
          :species_guess => row[0],
          :observed_on_string => row[1],
          :description => row[2],
          :place_guess => row[3],
          :time_zone => current_user.time_zone,
          :latitude => row[4], 
          :longitude => row[5]
        )
        obs.set_taxon_from_species_guess
        if obs.georeferenced?
          obs.location_is_exact = true
        elsif row[3]
          places = Ym4r::GmPlugin::Geocoding.get(row[3]) unless row[3].blank?
          unless places.blank?
            obs.latitude = places.first.latitude
            obs.longitude = places.first.longitude
            obs.location_is_exact = false
          end
        end
        obs.tag_list = row[6]
        @hasInvalid ||= !obs.valid?
        @observations << obs
        @rows << row
        row_num += 1
        if row_num >= max_rows
          flash[:notice] = t(:too_many_observations_csv, :max_rows => max_rows)
          break
        end
      end
    rescue CSV::MalformedCSVError => e
      flash[:error] = <<-EOT
        Your CSV had a formatting problem. Try removing any strange
        characters and unclosed quotes, and if the problem persists, please
        <a href="mailto:#{CONFIG.help_email}">email us</a> the file and we'll
        figure out the problem.
      EOT
      redirect_to :action => 'import'
      return
    end
  end

  # Edit a batch of observations
  def edit_batch
    observation_ids = params[:o].is_a?(String) ? params[:o].split(',') : []
    @observations = Observation.all(
      :conditions => [
        "id in (?) AND user_id = ?", observation_ids, current_user])
    @observations.map do |o|
      if o.coordinates_obscured?
        o.latitude = o.private_latitude
        o.longitude = o.private_longitude
      end
      o
    end
  end
  
  def delete_batch
    @observations = Observation.all(
      :conditions => [
        "id in (?) AND user_id = ?", params[:o].split(','), current_user])
    @observations.each do |observation|
      observation.destroy if observation.user == current_user
    end
    
    respond_to do |format|
      format.html do
        flash[:notice] = "Observations deleted."
        redirect_to observations_by_login_path(current_user.login)
      end
      format.js { render :text => "Observations deleted.", :status => 200 }
    end
  end
  
  # Import observations from external sources
  def import
  end
  
  def import_photos
    photos = Photo.descendent_classes.map do |klass|
      retrieve_photos(params[klass.to_s.underscore.pluralize.to_sym], 
        :user => current_user, :photo_class => klass)
    end.flatten.compact
    @observations = photos.map{|p| p.to_observation}
    @observation_photos = ObservationPhoto.includes(:photo, :observation).
      where("photos.native_photo_id IN (?)", photos.map(&:native_photo_id))
    @step = 2
    render :template => 'observations/new_batch'
  rescue Timeout::Error => e
    flash[:error] = "Sorry, that photo provider isn't responding at the moment. Please try again later."
    Rails.logger.error "[ERROR #{Time.now}] Timeout: #{e}"
    redirect_to :action => "import"
  end

  def import_sounds
      sounds = Sound.from_observation_params(params, 0, current_user)
      @observations = sounds.map{|s| s.to_observation}
      @step = 2
      render :template => 'observations/new_batch'
  end
  
  def add_from_list
    @order = params[:order] || "alphabetical"
    if @list = List.find_by_id(params[:id])
      @cache_key = {:controller => "observations", :action => "add_from_list", :id => @list.id, :order => @order}
      unless fragment_exist?(@cache_key)
        @listed_taxa = @list.listed_taxa.order_by(@order).paginate(:include => {:taxon => [:photos, :taxon_names]}, :page => 1, :per_page => 1000)
        @listed_taxa_alphabetical = @listed_taxa.sort! {|a,b| a.taxon.default_name.name <=> b.taxon.default_name.name}
        @listed_taxa = @listed_taxa_alphabetical if @order == ListedTaxon::ALPHABETICAL_ORDER
        @taxon_ids_by_name = {}
        ancestor_ids = @listed_taxa.map {|lt| lt.taxon_ancestor_ids.to_s.split('/')}.flatten.uniq
        @orders = Taxon.all(:conditions => ["rank = 'order' AND id IN (?)", ancestor_ids], :order => "ancestry")
        @families = Taxon.all(:conditions => ["rank = 'family' AND id IN (?)", ancestor_ids], :order => "ancestry")
      end
    end
    @user_lists = current_user.lists.all(:limit => 100)
    
    respond_to do |format|
      format.html
      format.mobile { render "add_from_list.html.erb" }
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
    @taxa = Taxon.all(:conditions => ["id in (?)", params[:taxa]], :include => :taxon_names)
    if @taxa.blank?
      flash[:error] = "No taxa selected!"
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
    search_params, find_options = get_search_params(params)
    search_params.update(:user_id => @selected_user.id)
    if search_params[:q].blank?
      get_paginated_observations(search_params, find_options)
    else
      search_observations(search_params, find_options)
    end
    
    respond_to do |format|
      format.html do
        @observer_provider_authorizations = @selected_user.provider_authorizations
        if logged_in? && @selected_user.id == current_user.id
          @project_users = current_user.project_users.all(:include => :project, :order => "projects.title")
          if @proj_obs_errors = Rails.cache.read("proj_obs_errors_#{current_user.id}") 
            @project = Project.find_by_id(@proj_obs_errors[:project_id])
            @proj_obs_errors_obs = current_user.observations.all(:conditions => ["id IN (?)", @proj_obs_errors[:errors].keys], :include => [:photos, :taxon])
            Rails.cache.delete("proj_obs_errors_#{current_user.id}")
          end
        end
        
        if (partial = params[:partial]) && PARTIALS.include?(partial)
          return render_observations_partial(partial)
        end
      end
      
      format.mobile
      
      format.json do
        render_observations_to_json
      end
      
      format.kml do
        render_observations_to_kml(
          :snippet => "#{CONFIG.site_name} Feed for User: #{@selected_user.login}",
          :description => "#{CONFIG.site_name} Feed for User: #{@selected_user.login}",
          :name => "#{CONFIG.site_name} Feed for User: #{@selected_user.login}"
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
      flash[:error] = "You don't have permission to do that."
      redirect_back_or_default(root_url)
      return
    end
    path_for_csv = private_page_cache_path("observations/#{@selected_user.login}.all.csv")
    delayed_csv(path_for_csv, @selected_user)
  end
  
  # shows observations in need of an ID
  def id_please
    params[:order_by] ||= "created_at"
    params[:order] ||= "desc"
    search_params, find_options = get_search_params(params)
    search_params = site_search_params(search_params)
    find_options.update(
      :per_page => 10,
      :include => [
        :user, 
        {:taxon => [:taxon_names]}, 
        :tags, 
        :photos, 
        {:identifications => [{:taxon => [:taxon_names]}, :user]}, 
        {:comments => [:user]}
      ]
    )
    if search_params[:has]
      search_params[:has] = (search_params[:has].split(',') + ['id_please']).flatten.uniq
    else
      search_params[:has] = 'id_please'
    end
    
    if search_params[:q].blank?
      get_paginated_observations(search_params, find_options)
    else
      search_observations(search_params, find_options)
    end
    
    @top_identifiers = User.all(:order => "identifications_count DESC", 
      :limit => 5)
  end
  
  # Renders observation components as form fields for inclusion in 
  # observation-picking form widgets
  def selector
    search_params, find_options = get_search_params(params)

    @observations = Observation.latest.query(search_params).paginate(find_options)
      
    respond_to do |format|
      format.html { render :layout => false, :partial => 'selector'}
      # format.js
    end
  end
  
  def tile_points
    # Project tile coordinates into lat/lon using a Spherical Merc projection
    merc = SPHERICAL_MERCATOR
    tile_size = 256
    x, y, zoom = params[:x].to_i, params[:y].to_i, params[:zoom].to_i
    swlng, swlat = merc.from_pixel_to_ll([x * tile_size, (y+1) * tile_size], zoom)
    nelng, nelat = merc.from_pixel_to_ll([(x+1) * tile_size, y * tile_size], zoom)
    @observations = Observation.in_bounding_box(swlat, swlng, nelat, nelng).all(
      :select => "id, species_guess, latitude, longitude, user_id, description, private_latitude, private_longitude, time_observed_at",
      :include => [:user, :photos], :limit => 500, :order => "id DESC")
    
    respond_to do |format|
      format.json do
        render :json => @observations.to_json(
          :only => [:id, :species_guess, :latitude, :longitude],
          :include => {
            :user => {:only => :login}
          },
          :methods => [:image_url, :short_description])
      end
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
    respond_to do |format|
      format.html
    end
  end
  
  def nearby
    @lat = params[:latitude].to_f
    @lon = params[:longitude].to_f
    if @lat && @lon
      @latrads = @lat * (Math::PI / 180)
      @lonrads = @lon * (Math::PI / 180)
      @observations = Observation.search(:geo => [latrads,lonrads], 
        :page => params[:page],
        :without => {:observed_on => 0},
        :order => "@geodist asc, observed_on desc") rescue []
    end
    
    @observations ||= Observation.latest.paginate(:page => params[:page])
    
    request.format = :mobile
    respond_to do |format|
      format.mobile
    end
  end
  
  def add_nearby
    @observation = current_user.observations.build(:time_zone => current_user.time_zone)
    request.format = :mobile
    respond_to do |format|
      format.mobile
    end
  end
  
  def project
    @project = Project.find(params[:id]) rescue nil
    unless @project
      flash[:error] = "That project doesn't exist."
      redirect_to request.env["HTTP_REFERER"] || projects_path
      return
    end
    
    unless request.format == :mobile
      search_params, find_options = get_search_params(params)
      search_params[:projects] = @project.id
      if search_params[:q].blank?
        get_paginated_observations(search_params, find_options)
      else
        search_observations(search_params, find_options)
      end
    end
    
    @project_observations = @project.project_observations.all(
      :conditions => ["observation_id IN (?)", @observations],
      :include => [{:curator_identification => [:taxon, :user]}])
    @project_observations_by_observation_id = @project_observations.index_by(&:observation_id)
    
    @kml_assets = @project.project_assets.select{|pa| pa.asset_file_name =~ /\.km[lz]$/}
    
    respond_to do |format|
      format.html do
        if (partial = params[:partial]) && PARTIALS.include?(partial)
          return render_observations_partial(partial)
        end
      end
      format.json do
        render_observations_to_json
      end
      format.atom do
        @updated_at = Observation.first(:order => 'updated_at DESC').updated_at
        render :action => "index"
      end
      format.csv do
        render :text => ProjectObservation.to_csv(@project_observations, :user => current_user)
      end
      format.kml do
        render_observations_to_kml(
          :snippet => "#{@project.title.html_safe} Observations", 
          :description => "Observations feed for the #{CONFIG.site_name} project '#{@project.title.html_safe}'", 
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
      format.mobile
    end
  end
  
  def project_all
    @project = Project.find(params[:id]) rescue nil
    unless @project
      flash[:error] = "That project doesn't exist."
      redirect_to request.env["HTTP_REFERER"] || projects_path
      return
    end
    
    unless @project.curated_by?(current_user)
      flash[:error] = "Only project curators can do that."
      redirect_to request.env["HTTP_REFERER"] || @project
      return
    end

    path_for_csv = private_page_cache_path("observations/project/#{@project.slug}.all.csv")
    delayed_csv(path_for_csv, @project)
  end
  
  def identotron
    @observation = Observation.find_by_id((params[:observation] || params[:observation_id]).to_i)
    @taxon = Taxon.find_by_id(params[:taxon].to_i)
    @q = params[:q] unless params[:q].blank?
    if @observation
      @places = @observation.places.try(:reverse)
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
  end

  def fields
    @project = Project.find(params[:project_id]) rescue nil
    @observation_fields = if @project
      @project.observation_fields
    elsif params[:observation_fields]
      ObservationField.where("id IN (?)", params[:observation_fields])
    else
      @observation_fields = ObservationField.
        includes(:observation_field_values => {:observation => :user}).
        where("users.id = ?", current_user).
        limit(10).
        order("observation_field_values.id DESC")
    end
    render :layout => false
  end

  def photo
    @observations = []
    unless params[:files].blank?
      params[:files].each_with_index do |file, i|
        lp = LocalPhoto.new(:file => file, :user => current_user)
        o = lp.to_observation
        if params[:observations] && obs_params = params[:observations][i]
          obs_params.each do |k,v|
            o.send("#{k}=", v) unless v.blank?
          end
        end
        o.save
        @observations << o
      end
    end
    respond_to do |format|
      format.json do
        render_observations_to_json(:include => {
          :taxon => {
            :only => [:name, :id, :rank, :rank_level, :is_iconic], 
            :methods => [:default_name, :image_url, :iconic_taxon_name, :conservation_status_name],
            :include => {
              :iconic_taxon => {
                :only => [:id, :name]
              },
              :taxon_names => {
                :only => [:id, :name, :lexicon]
              }
            }
          }
        })
      end
    end
  end

  def stats
    @headless = @footless = true
    search_params, find_options = get_search_params(params)
    @stats_adequately_scoped = stats_adequately_scoped?
  end

  def taxon_stats
    search_params, find_options = get_search_params(params, :skip_order => true, :skip_pagination => true)
    scope = Observation.query(search_params).scoped
    scope = scope.where("1 = 2") unless stats_adequately_scoped?
    taxon_counts_scope = scope.
      joins(:taxon).
      where("taxa.rank_level <= ?", Taxon::SPECIES_LEVEL)
    taxon_counts_sql = <<-SQL
      SELECT
        o.taxon_id,
        count(*) AS count_all
      FROM
        (#{taxon_counts_scope.to_sql}) AS o
      GROUP BY
        o.taxon_id
      ORDER BY count_all desc
      LIMIT 5
    SQL
    @taxon_counts = ActiveRecord::Base.connection.execute(taxon_counts_sql)
    @taxa = Taxon.where("id in (?)", @taxon_counts.map{|r| r['taxon_id']}).includes({:taxon_photos => :photo}, :taxon_names)
    @taxa_by_taxon_id = @taxa.index_by(&:id)
    rank_counts_sql = <<-SQL
      SELECT
        o.rank_name,
        count(*) AS count_all
      FROM
        (#{scope.joins(:taxon).select("DISTINCT ON (taxa.id) taxa.rank AS rank_name").to_sql}) AS o
      GROUP BY o.rank_name
    SQL
    @rank_counts = ActiveRecord::Base.connection.execute(rank_counts_sql)
    respond_to do |format|
      format.json do
        render :json => {
          :total => @rank_counts.map{|r| r['count_all'].to_i}.sum,
          :taxon_counts => @taxon_counts.map{|row|
            {
              :id => row['taxon_id'],
              :count => row['count_all'],
              :taxon => @taxa_by_taxon_id[row['taxon_id'].to_i].as_json(
                :methods => [:default_name, :image_url, :iconic_taxon_name, :conservation_status_name],
                :only => [:id, :name, :rank, :rank_level]
              )
            }
          },
          :rank_counts => @rank_counts.inject({}) {|memo,row|
            memo[row['rank_name']] = row['count_all']
            memo
          }
        }
      end
    end
  end

  def user_stats
    search_params, find_options = get_search_params(params, :skip_order => true, :skip_pagination => true)
    scope = Observation.query(search_params).scoped
    scope = scope.where("1 = 2") unless stats_adequately_scoped?
    user_counts_sql = <<-SQL
      SELECT
        o.user_id,
        count(*) AS count_all
      FROM
        (#{scope.to_sql}) AS o
      GROUP BY
        o.user_id
      ORDER BY count_all desc
      LIMIT 5
    SQL
    @user_counts = ActiveRecord::Base.connection.execute(user_counts_sql)
    user_taxon_counts_sql = <<-SQL
      SELECT
        o.user_id,
        count(*) AS count_all
      FROM
        (#{scope.select("DISTINCT ON (observations.taxon_id) observations.user_id").joins(:taxon).where("taxa.rank_level <= ?", Taxon::SPECIES_LEVEL).to_sql}) AS o
      GROUP BY
        o.user_id
      ORDER BY count_all desc
      LIMIT 5
    SQL
    @user_taxon_counts = ActiveRecord::Base.connection.execute(user_taxon_counts_sql)
    @users = User.where("id in (?)", [@user_counts.map{|r| r['user_id']}, @user_taxon_counts.map{|r| r['user_id']}].flatten.uniq)
    @users_by_id = @users.index_by(&:id)
    respond_to do |format|
      format.json do
        render :json => {
          :total => scope.select("DISTINCT observations.user_id").count,
          :most_observations => @user_counts.map{|row|
            {
              :id => row['user_id'],
              :count => row['count_all'],
              :user => @users_by_id[row['user_id'].to_i].as_json(
                :only => [:id, :name, :login],
                :methods => [:user_icon_url]
              )
            }
          },
          :most_species => @user_taxon_counts.map{|row|
            {
              :id => row['user_id'],
              :count => row['count_all'],
              :user => @users_by_id[row['user_id'].to_i].as_json(
                :only => [:id, :name, :login],
                :methods => [:user_icon_url]
              )
            }
          }
        }
      end
    end
  end

## Protected / private actions ###############################################
  private

  def stats_adequately_scoped?
    if params[:d1] && params[:d2]
      d1 = (Date.parse(params[:d1]) rescue Date.today)
      d2 = (Date.parse(params[:d2]) rescue Date.today)
      return false if d2 - d1 > 366
    end
    !(params[:d1].blank? && params[:projects].blank? && params[:place_id].blank? && params[:user_id].blank?)
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
    existing = photo_class.includes(:user).where("native_photo_id IN (?)", native_photo_ids).index_by{|p| p.native_photo_id}
    
    photo_list.uniq.each do |photo_id|
      if (photo = existing[photo_id]) || options[:sync]
        api_response = photo_class.get_api_response(photo_id, :user => current_user)
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
          LocalPhoto.new(:file => photo_id, :user => current_user) unless photo_id.blank?
        else
          api_response ||= photo_class.get_api_response(photo_id, :user => current_user)
          if api_response
            photo_class.new_from_api_response(api_response, :user => current_user)
          end
        end
      end
      
      if photo.blank?
        Rails.logger.error "[ERROR #{Time.now}] Failed to get photo for photo_class: #{photo_class}, photo_id: #{photo_id}"
      elsif photo.valid?
        photos << photo
      else
        Rails.logger.error "[ERROR #{Time.now}] #{current_user} tried to save an observation with an invalid photo (#{photo}): #{photo.errors.full_messages.to_sentence}"
      end
    end
    photos
  end
  
  # Processes params for observation requests.  Designed for use with 
  # will_paginate and standard observations query API
  def get_search_params(params, options = {})
    # The original params is important for things like pagination, so we 
    # leave it untouched.
    search_params = params.clone
    
    @swlat = search_params[:swlat] unless search_params[:swlat].blank?
    @swlng = search_params[:swlng] unless search_params[:swlng].blank?
    @nelat = search_params[:nelat] unless search_params[:nelat].blank?
    @nelng = search_params[:nelng] unless search_params[:nelng].blank?
    unless search_params[:place_id].blank?
      @place = begin
        Place.find(search_params[:place_id])
      rescue ActiveRecord::RecordNotFound
        nil
      end
    end
    
    @q = search_params[:q].to_s unless search_params[:q].blank?
    if Observation::SPHINX_FIELD_NAMES.include?(search_params[:search_on])
      @search_on = search_params[:search_on]
    end
    
    find_options = {
      :include => [:user, {:taxon => [:taxon_names]}, :taggings, {:observation_photos => :photo}],
      :page => search_params[:page]
    }
    unless options[:skip_pagination]
      find_options[:page] = 1 if find_options[:page].to_i == 0
      find_options[:per_page] = @prefs["per_page"] if @prefs
      if !search_params[:per_page].blank?
        find_options.update(:per_page => search_params[:per_page])
      elsif !search_params[:limit].blank?
        find_options.update(:per_page => search_params[:limit])
      end
      
      if find_options[:per_page] && find_options[:per_page].to_i > 200
        find_options[:per_page] = 200
      end
      find_options[:per_page] = 30 if find_options[:per_page].to_i == 0
    end
    
    if find_options[:limit] && find_options[:limit].to_i > 200
      find_options[:limit] = 200
    end
    
    unless request.format && request.format.html?
      find_options[:include] = [{:taxon => :taxon_names}, {:observation_photos => :photo}, :user]
    end
    
    # iconic_taxa
    if search_params[:iconic_taxa]
      # split a string of names
      if search_params[:iconic_taxa].is_a? String
        search_params[:iconic_taxa] = search_params[:iconic_taxa].split(',')
      end
      
      # resolve taxa entered by name
      search_params[:iconic_taxa] = search_params[:iconic_taxa].map do |it|
        it = it.last if it.is_a?(Array)
        if it.to_i == 0
          Taxon::ICONIC_TAXA_BY_NAME[it]
        else
          Taxon::ICONIC_TAXA_BY_ID[it]
        end
      end
      @iconic_taxa = search_params[:iconic_taxa]
    end
    
    # taxon
    unless search_params[:taxon_id].blank?
      @observations_taxon_id = search_params[:taxon_id] 
      @observations_taxon = Taxon.find_by_id(@observations_taxon_id.to_i)
    end
    unless search_params[:taxon_name].blank?
      @observations_taxon_name = search_params[:taxon_name].to_s
      taxon_name_conditions = ["taxon_names.name = ?", @observations_taxon_name]
      includes = nil
      unless @iconic_taxa.blank?
        taxon_name_conditions[0] += " AND taxa.iconic_taxon_id IN (?)"
        taxon_name_conditions << @iconic_taxa
        includes = :taxon
      end
      begin
        @observations_taxon = TaxonName.first(:include => includes, 
          :conditions => taxon_name_conditions).try(:taxon)
      rescue ActiveRecord::StatementInvalid => e
        raise e unless e.message =~ /invalid byte sequence/
        taxon_name_conditions[1] = @observations_taxon_name.encode('UTF-8')
        @observations_taxon = TaxonName.first(:include => includes, 
          :conditions => taxon_name_conditions).try(:taxon)
      end
    end
    search_params[:taxon] = @observations_taxon
    
    if search_params[:has]
      if search_params[:has].is_a?(String)
        search_params[:has] = search_params[:has].split(',')
      end
      @id_please = true if search_params[:has].include?('id_please')
      @with_photos = true if search_params[:has].include?('photos')
    end
    
    @quality_grade = search_params[:quality_grade]
    @identifications = search_params[:identifications]
    @out_of_range = search_params[:out_of_range]
    @license = search_params[:license]
    @photo_license = search_params[:photo_license]
    
    unless options[:skip_order]
      search_params[:order_by] = "created_at" if search_params[:order_by] == "observations.id"
      if ORDER_BY_FIELDS.include?(search_params[:order_by].to_s)
        @order_by = search_params[:order_by]
        @order = if %w(asc desc).include?(search_params[:order].to_s.downcase)
          search_params[:order]
        else
          'desc'
        end
      else
        @order_by = "observations.id"
        @order = "desc"
      end
      search_params[:order_by] = "#{@order_by} #{@order}"
    end
    
    # date
    date_pieces = [search_params[:year], search_params[:month], search_params[:day]]
    unless date_pieces.map{|d| d.blank? ? nil : d}.compact.blank?
      search_params[:on] = date_pieces.join('-')
    end
    if search_params[:on].to_s =~ /^\d{4}/
      @observed_on = search_params[:on]
      @observed_on_year, @observed_on_month, @observed_on_day = @observed_on.split('-').map{|d| d.to_i}
    end
    @observed_on_year ||= search_params[:year].to_i unless search_params[:year].blank?
    @observed_on_month ||= search_params[:month].to_i unless search_params[:month].blank?
    @observed_on_day ||= search_params[:day].to_i unless search_params[:day].blank?

    # observation fields
    ofv_params = search_params.select{|k,v| k =~ /^field\:/}
    unless ofv_params.blank?
      @ofv_params = {}
      ofv_params.each do |k,v|
        @ofv_params[k] = {
          :normalized_name => ObservationField.normalize_name(k),
          :value => v
        }
      end
      observation_fields = ObservationField.where("lower(name) IN (?)", @ofv_params.map{|k,v| v[:normalized_name]})
      @ofv_params.each do |k,v|
        v[:observation_field] = observation_fields.detect do |of|
          v[:normalized_name] == ObservationField.normalize_name(of.name)
        end
      end
      @ofv_params.delete_if{|k,v| v[:observation_field].blank?}
      search_params[:ofv_params] = @ofv_params
    end

    @site = params[:site] unless params[:site].blank?

    @user = User.find_by_id(params[:user_id]) unless params[:user_id].blank?
    @projects = Project.where("id IN (?)", params[:projects]) unless params[:projects].blank?
    
    @filters_open = 
      !@q.nil? ||
      !@observations_taxon_id.blank? ||
      !@observations_taxon_name.blank? ||
      !@iconic_taxa.blank? ||
      @id_please == true ||
      !@with_photos.blank? ||
      !@identifications.blank? ||
      !@quality_grade.blank? ||
      !@out_of_range.blank? ||
      !@observed_on.blank? ||
      !@place.blank? ||
      !@ofv_params.blank?
    @filters_open = search_params[:filters_open] == 'true' if search_params.has_key?(:filters_open)
    
    [search_params, find_options]
  end
  
  # Either make a plain db query and return a WillPaginate collection or make 
  # a Sphinx call if there were query terms specified.
  def get_paginated_observations(search_params, find_options)
    if @q
      @observations = if @search_on
        find_options[:conditions] = update_conditions(
          find_options[:conditions], @search_on.to_sym => @q
        )
        Observation.query(search_params).search(find_options).compact
      else
        Observation.query(search_params).search(@q, find_options).compact
      end
    end
    if @observations.blank?
      @observations = Observation.query(search_params).includes(:observation_photos => :photo).paginate(find_options)
    end
    @observations
  rescue ThinkingSphinx::ConnectionError
    Rails.logger.error "[ERROR #{Time.now}] ThinkingSphinx::ConnectionError, hitting the db"
    find_options.delete(:class)
    find_options.delete(:classes)
    find_options.delete(:raise_on_stale)
    @observations = if @q
      Observation.query(search_params).all(
        :conditions => ["species_guess LIKE ?", "%#{@q}%"]).paginate(find_options)
    else
      Observation.query(search_params).paginate(find_options)
    end
  end
  
  def search_observations(search_params, find_options)
    sphinx_options = find_options.dup
    sphinx_options[:with] = {}
    
    if sphinx_options[:page] && sphinx_options[:page].to_i > 50
      if request.format && request.format.html?
        flash.now[:notice] = "Heads up: observation search can only load up to 50 pages"
      end
      sphinx_options[:page] = 50
      find_options[:page] = 50
    end
    
    if search_params[:has]
      # id please
      if search_params[:has].include?('id_please')
        sphinx_options[:with][:has_id_please] = true
      end
      
      # has photos
      if search_params[:has].include?('photos')
        sphinx_options[:with][:has_photos] = true
      end
      
      # geo
      if search_params[:has].include?('geo')
        sphinx_options[:with][:has_geo] = true 
      end
    end
    
    # Bounding box or near point
    if (!search_params[:swlat].blank? && !search_params[:swlng].blank? && 
        !search_params[:nelat].blank? && !search_params[:nelng].blank?)
      swlatrads = search_params[:swlat].to_f * (Math::PI / 180)
      swlngrads = search_params[:swlng].to_f * (Math::PI / 180)
      nelatrads = search_params[:nelat].to_f * (Math::PI / 180)
      nelngrads = search_params[:nelng].to_f * (Math::PI / 180)
      
      # The box straddles the 180th meridian...
      # This is a very stupid solution that just chooses the biggest of the
      # two sides straddling the meridian and queries in that.  Sphinx doesn't
      # seem to support multiple queries on the same attribute, so we can't do
      # the OR clause we do in the equivalent named scope.  Grr.  -kueda
      # 2009-04-10
      if swlngrads > 0 && nelngrads < 0
        lngrange = swlngrads.abs > nelngrads ? swlngrads..Math::PI : -Math::PI..nelngrads
        sphinx_options[:with][:longitude] = lngrange
        # sphinx_options[:with][:longitude] = swlngrads..Math::PI
        # sphinx_options[:with] = {:longitude => -Math::PI..nelngrads}
      else
        sphinx_options[:with][:longitude] = swlngrads..nelngrads
      end
      sphinx_options[:with][:latitude] = swlatrads..nelatrads
    elsif search_params[:lat] && search_params[:lng]
      latrads = search_params[:lat].to_f * (Math::PI / 180)
      lngrads = search_params[:lng].to_f * (Math::PI / 180)
      sphinx_options[:geo] = [latrads, lngrads]
      sphinx_options[:order] = "@geodist asc"
    end
    
    # identifications
    case search_params[:identifications]
    when 'most_agree'
      sphinx_options[:with][:identifications_most_agree] = true
    when 'some_agree'
      sphinx_options[:with][:identifications_some_agree] = true
    when 'most_disagree'
      sphinx_options[:with][:identifications_most_disagree] = true
    end
    
    # Taxon ID
    unless search_params[:taxon_id].blank?
      sphinx_options[:with][:taxon_id] = search_params[:taxon_id]
    end
    
    # Iconic taxa
    unless search_params[:iconic_taxa].blank?
      sphinx_options[:with][:iconic_taxon_id] = \
          search_params[:iconic_taxa].map do |iconic_taxon|
        iconic_taxon.nil? ? nil : iconic_taxon.id
      end
    end
    
    # User ID
    unless search_params[:user_id].blank?
      sphinx_options[:with][:user_id] = search_params[:user_id]
    end
    
    # User login
    unless search_params[:user].blank?
      sphinx_options[:with][:user] = search_params[:user]
    end
    
    # Ordering
    unless search_params[:order_by].blank?
      # observations.id is a more efficient sql clause, but it's not the name of a field in sphinx
      search_params[:order_by].gsub!(/observations\.id/, 'created_at')
      
      if !sphinx_options[:order].blank?
        sphinx_options[:order] += ", #{search_params[:order_by]}"
        sphinx_options[:sort_mode] = :extended
      elsif search_params[:order_by] =~ /\sdesc|asc/i
        sphinx_options[:order] = search_params[:order_by].split.first.to_sym
        sphinx_options[:sort_mode] = search_params[:order_by].split.last.downcase.to_sym
      else
        sphinx_options[:order] = search_params[:order_by].to_sym
      end
    end
    
    unless search_params[:projects].blank?
      sphinx_options[:with][:projects] = if search_params[:projects].is_a?(String) && search_params[:projects].index(',')
        search_params[:projects].split(',')
      else
        [search_params[:projects]].flatten
      end
    end

    unless search_params[:ofv_params].blank?
      ofs = search_params[:ofv_params].map do |k,v|
        v[:observation_field].blank? ? nil : v[:observation_field].id
      end.compact
      sphinx_options[:with][:observation_fields] = ofs unless ofs.blank?
    end
    
    # Sanitize query
    q = sanitize_sphinx_query(@q)
    
    # Field-specific searches
    obs_ids = if @search_on
      sphinx_options[:conditions] ||= {}
      # not sure why sphinx chokes on slashes when searching on attributes...
      sphinx_options[:conditions][@search_on.to_sym] = q.gsub(/\//, '')
      Observation.search_for_ids(find_options.merge(sphinx_options))
    else
      Observation.search_for_ids(q, find_options.merge(sphinx_options))
    end
    @observations = Observation.where("observations.id in (?)", obs_ids).
      order_by(search_params[:order_by]).
      includes(find_options[:include]).scoped

    # lame hacks
    unless search_params[:ofv_params].blank?
      search_params[:ofv_params].each do |k,v|
        next unless of = v[:observation_field]
        next if v[:value].blank?
        v[:observation_field].blank? ? nil : v[:observation_field].id
        @observations = @observations.has_observation_field(of.id, v[:value])
      end
    end

    if CONFIG.site_only_observations && params[:site].blank?
      @observations = @observations.where("observations.uri LIKE ?", "#{root_url}%")
    end

    @observations = WillPaginate::Collection.create(obs_ids.current_page, obs_ids.per_page, obs_ids.total_entries) do |pager|
      pager.replace(@observations.to_a)
    end

    begin
      @observations.total_entries
    rescue ThinkingSphinx::SphinxError, Riddle::OutOfBoundsError => e
      Rails.logger.error "[ERROR #{Time.now}] Failed sphinx search: #{e}"
      @observations = WillPaginate::Collection.new(1,30, 0)
    end
    @observations
  rescue ThinkingSphinx::ConnectionError
    Rails.logger.error "[ERROR #{Time.now}] Failed to connect to sphinx, falling back to db"
    get_paginated_observations(search_params, find_options)
  end
  
  # Refresh lists affected by taxon changes in a batch of new/edited
  # observations.  Note that if you don't set @skip_refresh_lists on the records
  # in @observations before this is called, this won't do anything
  def refresh_lists_for_batch
    return true if @observations.blank?
    taxa = @observations.select(&:skip_refresh_lists).map(&:taxon).uniq.compact
    return true if taxa.blank?
    List.delay.refresh_for_user(current_user, :taxa => taxa.map(&:id))
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
        flash.now[:notice] = "<strong>Preview</strong> of synced observation.  <a href=\"#{url_for}\">Undo?</a>"
      end
    else
      flash.now[:error] = "Sorry, we didn't find that photo."
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
      flash.now[:error] = "Sorry, Flickr isn't responding at the moment."
      Rails.logger.error "[ERROR #{Time.now}] Timeout: #{e}"
      Airbrake.notify(e, :request => request, :session => session)
      return
    end
    if fp && @flickr_photo && @flickr_photo.valid?
      @flickr_observation = @flickr_photo.to_observation
      sync_attrs = %w(description species_guess taxon_id observed_on 
        observed_on_string latitude longitude place_guess map_scale)
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
        flash.now[:notice] = "<strong>Preview</strong> of synced observation.  " +
          "<a href=\"#{url_for}\">Undo?</a>"
      end
      
      if (@existing_photo = Photo.find_by_native_photo_id(@flickr_photo.native_photo_id)) && 
          (@existing_photo_observation = @existing_photo.observations.first) && @existing_photo_observation.id != @observation.id
        msg = "Heads up: this photo is already associated with <a target='_blank' href='#{url_for(@existing_photo_observation)}'>another observation</a>"
        flash.now[:notice] = flash.now[:notice].blank? ? msg : "#{flash.now[:notice]}<br/>#{msg}"
      end
    else
      flash.now[:error] = "Sorry, we didn't find that photo."
    end
  end
  
  def sync_picasa_photo
    begin
      api_response = PicasaPhoto.get_api_response(params[:picasa_photo_id], :user => current_user)
    rescue Timeout::Error => e
      flash.now[:error] = "Sorry, Picasa isn't responding at the moment."
      Rails.logger.error "[ERROR #{Time.now}] Timeout: #{e}"
      Airbrake.notify(e, :request => request, :session => session)
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
      
      flash.now[:notice] = "<strong>Preview</strong> of synced observation.  " +
        "<a href=\"#{url_for}\">Undo?</a>"
    else
      flash.now[:error] = "Sorry, we didn't find that photo."
    end
  end

  def sync_local_photo
    unless @local_photo = Photo.find_by_id(params[:local_photo_id])
      flash.now[:error] = "That photo doesn't exist."
      return
    end
    if @local_photo.metadata.blank?
      flash.now[:error] = "Sorry, we don't have any metadata for that photo that we can use to set observation properties."
      return
    end
    o = @local_photo.to_observation
    PHOTO_SYNC_ATTRS.each do |sync_attr|
      @observation.send("#{sync_attr}=", o.send(sync_attr))
    end

    unless @observation.observation_photos.detect {|op| op.photo_id == @local_photo.id}
      @observation.observation_photos.build(:photo => @local_photo)
    end
    
    unless @observation.new_record?
      flash.now[:notice] = "<strong>Preview</strong> of synced observation.  " +
        "<a href=\"#{url_for}\">Undo?</a>"
    end
    
    if @existing_photo_observation = @local_photo.observations.where("observations.id != ?", @observation).first
      msg = "Heads up: this photo is already associated with <a target='_blank' href='#{url_for(@existing_photo_observation)}'>another observation</a>"
      flash.now[:notice] = flash.now[:notice].blank? ? msg : "#{flash.now[:notice]}<br/>#{msg}"
    end
  end
  
  def load_photo_identities
    unless logged_in?
      @photo_identity_urls = []
      @photo_identities = []
      return true
    end
    @photo_identities = Photo.descendent_classes.map do |klass|
      assoc_name = klass.to_s.underscore.split('_').first + "_identity"
      current_user.send(assoc_name) if current_user.respond_to?(assoc_name)
    end.compact
    
    reference_photo = @observation.try(:observation_photos).try(:first).try(:photo)
    reference_photo ||= @observations.try(:first).try(:observation_photos).try(:first).try(:photo)
    reference_photo ||= current_user.photos.order("id ASC").last
    if reference_photo
      assoc_name = reference_photo.class.to_s.underscore.split('_').first + "_identity"
      @default_photo_identity = current_user.send(assoc_name) if current_user.respond_to?(assoc_name)
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
    @default_photo_identity ||= @photo_identities.first
    @default_photo_source ||= if @default_photo_identity && @default_photo_identity.class.name =~ /Identity/
      @default_photo_identity.class.name.underscore.humanize.downcase.split.first
    elsif @default_photo_identity
      "facebook"
    end
    
    @default_photo_identity_url = nil
    @photo_identity_urls = @photo_identities.map do |identity|
      provider_name = if identity.is_a?(ProviderAuthorization)
        identity.provider_name
      else
        identity.class.to_s.underscore.split('_').first # e.g. FlickrIdentity=>'flickr'
      end
      url = "/#{provider_name.downcase}/photo_fields?context=user"
      @default_photo_identity_url = url if identity == @default_photo_identity
      "{title: '#{provider_name.capitalize}', url: '#{url}'}"
    end
    @photo_sources = @photo_identities.inject({}) do |memo, ident| 
      if ident.respond_to?(:source_options)
        memo[ident.class.name.underscore.humanize.downcase.split.first] = ident.source_options
      else
        memo[:facebook] = {
          :title => 'Facebook', 
          :url => '/facebook/photo_fields', 
          :contexts => [
            ["Your photos", 'user']
          ]
        }
      end
      memo
    end
  end

  def load_sound_identities
    unless logged_in?
      logger.info "not logged in"
      @sound_identities = []
      return true
    end

    @sound_identities = current_user.soundcloud_identity ? [current_user.soundcloud_identity] : []
  end
  
  def load_observation
    render_404 unless @observation = Observation.find_by_id(params[:id] || params[:observation_id], 
      :include => [
        :photos, 
        {:taxon => [:taxon_names]},
        :identifications
      ]
    )
  end
  
  def require_owner
    unless logged_in? && current_user.id == @observation.user_id
      msg = "You don't have permission to do that"
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
      data = @observations.map do |observation|
        item = {
          :instance => observation,
          :extra => {
            :taxon => observation.taxon,
            :iconic_taxon => observation.iconic_taxon,
            :user => {:login => observation.user.login}
          }
        }
        item[:html] = view_context.render_in_format(:html, :partial => partial, :object => observation)
        item
      end
      render :json => data
    else
      opts = options
      opts[:methods] ||= []
      opts[:methods] += [:short_description, :user_login, :iconic_taxon_name, :tag_list]
      opts[:methods].uniq!
      opts[:include] ||= {}
      if @ofv_params
        opts[:include][:observation_field_values] ||= {
          :except => [:observation_field_id],
          :include => {
            :observation_field => {
              :only => [:id, :datatype, :name]
            }
          }
        }
      end
      opts[:include][:taxon] ||= {
        :only => [:id, :name, :rank, :ancestry]
      }
      opts[:include][:iconic_taxon] ||= {:only => [:id, :name, :rank, :rank_level, :ancestry]}
      opts[:include][:user] ||= {:only => :login}
      opts[:include][:photos] ||= {
        :methods => [:license_code, :attribution],
        :except => [:original_url, :file_processing, :file_file_size, 
          :file_content_type, :file_file_name, :mobile, :metadata]
      }
      pagination_headers_for(@observations)
      if @observations.respond_to?(:scoped)
        @observations = @observations.includes({:observation_photos => :photo}, :photos, :iconic_taxon)
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
        @observations = @observations.includes(:observation_field_values => :observation_field)
      end
    end
    @observations = @observations.includes(:tags) if @observations.respond_to?(:scoped)
    render :text => @observations.to_csv(:only => only.map{|c| c.to_sym})
  end
  
  def render_observations_to_kml(options = {})
    @net_hash = options
    if params[:kml_type] == "network_link"
      @net_hash = {
        :id => "AllObs", 
        :link_id =>"AllObs", 
        :snippet => "#{CONFIG.site_name} Feed for Everyone", 
        :description => "#{CONFIG.site_name} Feed for Everyone", 
        :name => "#{CONFIG.site_name} Feed for Everyone", 
        :href => "#{root_url}#{request.fullpath}".gsub(/kml_type=network_link/, '')
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
    @project = Project.find_by_id(params[:project_id])
    @project ||= Project.find(params[:project_id]) rescue nil
    return unless @project
    @project_user = current_user.project_users.find_or_create_by_project_id(@project.id)
    return unless @project_user && @project_user.valid?
    tracking_code = params[:tracking_code] if @project.tracking_code_allowed?(params[:tracking_code])
    errors = []
    @observations.each do |observation|
      next if observation.new_record?
      po = @project.project_observations.build(:observation => observation, :tracking_code => tracking_code)
      unless po.save
        errors = (errors + po.errors.full_messages).uniq
      end
    end
     
    if !errors.blank?
      if request.format.html?
        flash[:error] = "Your observations couldn't be added to that project: #{errors.to_sentence}"
      else
        Rails.logger.error "[ERROR #{Time.now}] Failed to add #{@observations.size} obs to #{@project}: #{errors.to_sentence}"
      end
    end
  end
  
  def update_user_account
    current_user.update_attributes(params[:user]) unless params[:user].blank?
  end
  
  def render_observations_partial(partial)
    if @observations.empty?
      render(:text => '')
    else
      render(:partial => partial, :collection => @observations, :layout => false)
    end
  end

  def load_prefs
    @prefs = current_preferences
    if request.format && request.format.html?
      @view = params[:view] || current_user.try(:preferred_observations_view) || 'map'
    end
  end

  def site_search_params(search_params = {})
    if CONFIG.site_only_observations && params[:site].blank?
      search_params[:site] ||= FakeView.root_url
      @site ||= search_params[:site]
    end
    if (site_bounds = CONFIG.bounds) && params[:swlat].nil?
      search_params[:nelat] ||= site_bounds['nelat']
      search_params[:nelng] ||= site_bounds['nelng']
      search_params[:swlat] ||= site_bounds['swlat']
      search_params[:swlng] ||= site_bounds['swlng']
      @nelat ||= site_bounds['nelat']
      @nelng ||= site_bounds['nelng']
      @swlat ||= site_bounds['swlat']
      @swlng ||= site_bounds['swlng']
    end
    search_params
  end

  def delayed_csv(path_for_csv, parent, options = {})
    if parent.observations.count < 50
      Observation.generate_csv_for(parent, :path => path_for_csv)
      render :file => path_for_csv
    else
      cache_key = Observation.generate_csv_for_cache_key(parent)
      job_id = Rails.cache.read(cache_key)
      job = Delayed::Job.find_by_id(job_id)
      if job
        # Still working
      elsif File.exists? path_for_csv
        render :file => path_for_csv
        return
      else
        # no job id, no job, let's get this party started
        Rails.cache.delete(cache_key)
        job = Observation.delay.generate_csv_for(parent, :path => path_for_csv, :user => current_user)
        Rails.cache.write(cache_key, job.id, :expires_in => 1.hour)
      end
      prevent_caching
      render :status => :accepted, :text => "This file takes a little while to generate. It should be ready shortly at #{request.url}"
    end
  end
end
