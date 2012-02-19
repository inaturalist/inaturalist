class ObservationsController < ApplicationController
  caches_page :tile_points
  
  WIDGET_CACHE_EXPIRATION = 15.minutes
  caches_action :index, :by_login, :project,
    :expires_in => WIDGET_CACHE_EXPIRATION,
    :cache_path => Proc.new {|c| c.params}, 
    :if => Proc.new {|c| 
      c.session.blank? && # make sure they're logged out
      (c.request.format.geojson? || c.request.format.widget? || c.request.format.kml?) && 
      c.request.url.size < 250}
  caches_action :of,
    :expires_in => 1.day,
    :cache_path => Proc.new {|c| c.params},
    :if => Proc.new {|c| !c.request.format.html? }
  cache_sweeper :observation_sweeper, :only => [:update, :destroy]
  
  rescue_from ActionController::UnknownAction do
    unless @selected_user = User.find_by_login(params[:action])
      return render_404
    end
    by_login
  end
  
  before_filter :load_user_by_login, :only => [:by_login]
  before_filter :login_required, 
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
  before_filter :load_observation, :only => [:show, :edit, :edit_photos, 
    :update_photos, :destroy]
  before_filter :require_owner, :only => [:edit, :edit_photos, 
    :update_photos, :destroy]
  before_filter :return_here, :only => [:index, :by_login, :show, :id_please, 
    :import, :add_from_list]
  before_filter :curator_required, :only => [:curation]
  before_filter :load_photo_identities, :only => [:new, :new_batch, :edit,
    :update, :edit_batch, :create, :import, :import_photos, :new_from_list]
  before_filter :photo_identities_required, :only => [:import_photos]
  after_filter :refresh_lists_for_batch, :only => [:create, :update]
  
  MOBILIZED = [:add_from_list, :nearby, :add_nearby, :project, :by_login, :index, :show]
  before_filter :unmobilized, :except => MOBILIZED
  before_filter :mobilized, :only => MOBILIZED
  
  ORDER_BY_FIELDS = %w"place user created_at observed_on species_guess"
  REJECTED_FEED_PARAMS = %w"page view filters_open partial"
  REJECTED_KML_FEED_PARAMS = REJECTED_FEED_PARAMS + %w"swlat swlng nelat nelng"
  DISPLAY_ORDER_BY_FIELDS = {
    'place' => 'place',
    'user' => 'user',
    'created_at' => 'date added',
    'observations.id' => 'date added',
    'id' => 'date added',
    'observed_on' => 'date observed',
    'species_guess' => 'species name'
  }
  PARTIALS = %w(cached_component observation_component observation mini)

  # GET /observations
  # GET /observations.xml
  def index
    @update = params[:update] # this is ONLY for RJS calls.  Lame.  Sorry.
    
    search_params, find_options = get_search_params(params)
    
    if search_params[:q].blank?
      @observations = if perform_caching
        cache_params = params.reject{|k,v| %w(controller action format partial).include?(k.to_s)}
        cache_params[:page] ||= 1
        cache_key = "obs_index_#{Digest::MD5.hexdigest(cache_params.to_s)}"
        Rails.cache.fetch(cache_key, :expires_in => 5.minutes) do
          get_paginated_observations(search_params, find_options)
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
        @view = params[:view] ||= 'map'
        if (partial = params[:partial]) && PARTIALS.include?(partial)
          return render_observations_partial(partial)
        end
      end

      format.json do
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

            @template.template_format = :html
            item[:html] = render_to_string(:partial => partial, :object => observation)
            @template.template_format = :json
            item
          end
          render :json => data
        else
          render :json => @observations.to_json(
            :methods => [:short_description, :user_login, :iconic_taxon_name],
            :include => {
              :iconic_taxon => {},
              :user => {:only => :login},
              :photos => {}
            }
          )
        end
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
          :snippet => "iNaturalist Feed for Everyone", 
          :description => "iNaturalist Feed for Everyone", 
          :name => "iNaturalist Feed for Everyone"
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
    if request.format.html?
      redirect_to observations_path(:taxon_id => params[:id])
      return
    end
    unless @taxon = Taxon.find_by_id(params[:id].to_i)
      render_404 && return
    end
    @observations = Observation.of(@taxon).all(
      :include => [:user, :taxon, :iconic_taxon, :photos], 
      :order => "observations.id desc", 
      :limit => 500).sort_by{|o| [o.quality_grade == "research" ? 1 : 0, id]}
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
    @previous = @observation.user.observations.first(:conditions => ["id < ?", @observation.id], :order => "id DESC")
    @prev = @previous
    @next = @observation.user.observations.first(:conditions => ["id > ?", @observation.id], :order => "id ASC")
    @quality_metrics = @observation.quality_metrics.all(:include => :user)
    if logged_in?
      @user_quality_metrics = @observation.quality_metrics.select{|qm| qm.user_id == current_user.id}
    end
    
    respond_to do |format|
      format.html do
        # always display the time in the zone in which is was observed
        Time.zone = @observation.user.time_zone
                
        @identifications = @observation.identifications.all(:include => [:user, {:taxon => :photos}])
        @owners_identification = @identifications.detect do |ident|
          ident.user_id == @observation.user_id
        end
        if logged_in?
          @viewers_identification = @identifications.detect do |ident|
            ident.user_id == current_user.id
          end
        end
        
        @identifications_by_taxon = @identifications.select do |ident|
          ident.user_id != ident.observation.user_id
        end.group_by{|i| i.taxon}
        @identifications_by_taxon = @identifications_by_taxon.sort_by do |row|
          row.last.size
        end.reverse
        
        if logged_in?
          # Make sure the viewer's ID is first in its group
          @identifications_by_taxon.each_with_index do |pair, i|
            if pair.last.map(&:user_id).include?(current_user.id)
              pair.last.delete(@viewers_identification)
              identifications = [@viewers_identification] + pair.last
              @identifications_by_taxon[i] = [pair.first, identifications]
            end
          end
          
          @projects = Project.all(
            :joins => [:project_users], 
            :limit => 1000, 
            :conditions => ["project_users.user_id = ?", current_user]
          ).sort_by{|p| p.title}
        end
        
        @places = @observation.places
        
        @project_observations = @observation.project_observations.all(:limit => 100)
        @project_observations_by_project_id = @project_observations.index_by(&:project_id)
        if logged_in?
          @project_invitations = @observation.project_invitations.all(:limit => 100)
          @project_invitations_by_project_id = @project_invitations.index_by(&:project_id)
        end
        
        @comments_and_identifications = (@observation.comments.all + 
          @identifications).sort_by{|r| r.created_at}
        
        @photos = @observation.observation_photos.sort_by do |op| 
          op.position || @observation.photos.size + op.id.to_i
        end.map{|op| op.photo}
        
        if @observation.observed_on
          @day_observations = Observation.by(@observation.user).on(@observation.observed_on).paginate(:page => 1, :per_page => 14, :include => [:photos])
        end
        
        if params[:partial]
          return render(:partial => params[:partial], :object => @observation,
            :layout => false)
        end
      end
      
      format.mobile
       
      format.xml { render :xml => @observation }
      
      format.json do
        render :json => @observation.to_json(:methods => [:user_login, :iconic_taxon_name])
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
    options = {}
    options[:id_please] ||= params[:id_please]
    
    @taxon = Taxon.find_by_id(params[:taxon_id].to_i) unless params[:taxon_id].blank?
    unless params[:taxon_name].blank?
      @taxon ||= TaxonName.first(:conditions => [
        "lower(name) = ?", params[:taxon_name].to_s.strip.gsub(/[\s_]+/, ' ').downcase]
      ).try(:taxon)
    end
    
    if !params[:project_id].blank?
      @project = if params[:project_id].to_i == 0
        Project.find(params[:project_id])
      else
        Project.find_by_id(params[:project_id].to_i)
      end
      if @project
        @project_curators = @project.project_users.all(:conditions => {:role => "curator"})
        if @place = @project.rule_place
          @place_geometry = PlaceGeometry.without_geom.first(:conditions => {:place_id => @place})
        end
      end
    end
    options[:time_zone] = current_user.time_zone
    @observation = Observation.new(options)
    
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
    
    # this should happen AFTER photo syncing so params can override attrs 
    # from the photo
    [:latitude, :longitude, :place_guess, :location_is_exact, :map_scale,
        :positional_accuracy, :positioning_device, :positioning_method,
        :observed_on_string].each do |obs_attr|
      @observation.send("#{obs_attr}=", params[obs_attr]) unless params[obs_attr].blank?
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
    
    @observation_fields = ObservationField.all(:order => "id DESC", :limit => 5)
    
    respond_to do |format|
      format.html do
        @observations = [@observation]
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
    @observation_fields = ObservationField.all(:order => "id DESC", :limit => 5)
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
      observation.delete('fieldset_index') if observation[:fieldset_index]
      o = Observation.new(observation)
      o.user = current_user
      o.user_agent = request.user_agent
      # Get photos
      Photo.descendent_classes.each do |klass|
        klass_key = klass.to_s.underscore.pluralize.to_sym
        if params[klass_key] && params[klass_key][fieldset_index]
          o.photos << retrieve_photos(params[klass_key][fieldset_index], 
            :user => current_user, :photo_class => klass)
        end
      end
      o
    end
    
    if params[:project_id] && !current_user.project_users.find_by_project_id(params[:project_id])
      # JSON conditions is a bit of a hack to accomodate mobile clients
      unless params[:accept_terms] || request.format.json?
        msg = "You need check that you agree to the project terms before joining the project"
        @project = Project.find_by_id(params[:project_id])
        @project_curators = @project.project_users.all(:conditions => {:role => "curator"})
        respond_to do |format|
          format.html do
            flash[:error] = msg
            render :action => 'new'
          end
          format.json do
            render :json => {:errors => msg}, :status => :unprocessable_entity
          end
        end
        return
      end
    end
    
    self.current_user.observations << @observations
    
    create_project_observations
    
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
              :latitude => o.latitude, 
              :longitude => o.longitude, 
              :place_guess => o.place_guess, 
              :observed_on_string => o.observed_on_string,
              :location_is_exact => o.location_is_exact,
              :map_scale => o.map_scale,
              :positional_accuracy => o.positional_accuracy,
              :positioning_method => o.positional_accuracy,
              :positioning_device => o.positional_accuracy
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
          render :json => {:errors => @observations.map{|o| o.errors.full_messages}}, 
            :status => :unprocessable_entity
        else
          if @observations.size == 1 && is_iphone_app_2?
            render :json => @observations[0].to_json(:methods => [:user_login, :iconic_taxon_name])
          else
            render :json => @observations.to_json(:methods => [:user_login, :iconic_taxon_name])
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
    params[:observations] = [[params[:id], params[:observation]]] if params[:observation]
    
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
        params[:observations].map(&:first),
        observation_user
      ]
    )
    
    # Make sure there's no evil going on
    unique_user_ids = @observations.map(&:user_id).uniq
    if unique_user_ids.size > 1 || unique_user_ids.first != observation_user.id && !current_user.has_role?(:admin)
      flash[:error] = "You don't have permission to edit that observation."
      return redirect_to @observation
    end
    
    # Convert the params to a hash keyed by ID.  Yes, it's weird
    hashed_params = Hash[*params[:observations].to_a.flatten]
    errors = false
    @observations.each do |observation|      
      # Update the flickr photos
      # Note: this ignore photos thing is a total hack and should only be
      # included if you are updating observations but aren't including flickr
      # fields, e.g. when removing something from ID please
      unless params[:ignore_photos]
        # Get photos
        updated_photos = []
        old_photo_ids = observation.photo_ids
        Photo.descendent_classes.each do |klass|
          klass_key = klass.to_s.underscore.pluralize.to_sym
          if params[klass_key] && params[klass_key][observation.id.to_s]
            updated_photos += retrieve_photos(params[klass_key][observation.id.to_s], 
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
          Photo.send_later(:destroy_orphans, doomed_photo_ids)
        end
      end
      
      unless observation.update_attributes(hashed_params[observation.id.to_s])
        errors = true
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
        format.json { render :json => @observations.collect(&:errors), :status => :unprocessable_entity }
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
        format.json { render :json => msg, :status => :gone }
      else
        format.html do
          flash[:notice] = 'Observation(s) was successfully updated.'
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
            render :json => @observations[0].to_json(:methods => [:user_login, :iconic_taxon_name])
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
      flash[:notice] = "Observation was deleted."
      format.html { redirect_to(observations_by_login_path(@user.login)) }
      format.xml  { head :ok }
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
    csv = params[:upload][:datafile]
    max_rows = 100
    row_num = 0
    
    begin
      FasterCSV.parse(csv) do |row|
        next if row.blank?
        row = row.map{|item| Iconv.iconv('UTF8', 'LATIN1', item).to_s.strip}
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
        row_num += 1
        if row_num >= max_rows
          flash[:notice] = "You have a beehive of observations!<br /> We can only take your first #{max_rows} observations in every CSV"
          break
        end
      end
    rescue FasterCSV::MalformedCSVError => e
      flash[:error] = <<-EOT
        Your CSV had a formatting problem. Try removing any strange
        characters and unclosed quotes, and if the problem persists, please
        <a href="mailto:#{APP_CONFIG[:help_email]}">email us</a> the file and we'll
        figure out the problem.
      EOT
      redirect_to :action => 'import'
      return
    end
  end

  # Edit a batch of observations
  def edit_batch
    @observations = Observation.all(
      :conditions => [
        "id in (?) AND user_id = ?", params[:o].split(','), current_user])
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
    @observation_photos = ObservationPhoto.all(
      :conditions => ["photos.native_photo_id IN (?)", photos.map(&:native_photo_id)],
      :include => [:photo, :observation]
    )
    @step = 2
    render :template => 'observations/new_batch'
  rescue Timeout::Error => e
    flash[:error] = "Sorry, that photo provider isn't responding at the moment. Please try again later."
    Rails.logger.error "[ERROR #{Time.now}] Timeout: #{e}"
    redirect_to :action => "import"
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
    @prefs = current_preferences
    search_params, find_options = get_search_params(params)
    search_params.update(:user_id => @selected_user.id)
    if search_params[:q].blank?
      get_paginated_observations(search_params, find_options)
    else
      search_observations(search_params, find_options)
    end
    
    respond_to do |format|
      format.html do
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
        render :json => @observations.to_json(:methods => [:user_login, :iconic_taxon_name])
      end
      
      format.kml do
        render_observations_to_kml(
          :snippet => "iNaturalist Feed for User: #{@selected_user.login}",
          :description => "iNaturalist Feed for User: #{@selected_user.login}",
          :name => "iNaturalist Feed for User: #{@selected_user.login}"
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
  
  # shows observations in need of an ID
  def id_please
    search_params, find_options = get_search_params(params)
    search_params.update(:order_by => 'created_at DESC')
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

    @observations = Observation.latest.query(search_params).paginate(
      :all, find_options)
      
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
      :select => "id, species_guess, latitude, longitude, user_id, description, private_latitude, private_longitude",
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
      format.js do
        render :update do |page|
          page.replace_html "widget_preview_and_code", :partial => "widget_preview_and_code"
        end
      end
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
    
    respond_to do |format|
      format.mobile
    end
  end
  
  def add_nearby
    @observation = current_user.observations.build(:time_zone => current_user.time_zone)
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
    
    unless request.format.mobile?
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
    
    @kml_assets = @project.project_assets.all(:conditions => {
      :asset_content_type => "application/vnd.google-earth.kml+xml"})
    
    respond_to do |format|
      format.html do
        if (partial = params[:partial]) && PARTIALS.include?(partial)
          return render_observations_partial(partial)
        end
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
          :description => "Observations feed for the iNaturalist project '#{@project.title.html_safe}'", 
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
    
    respond_to do |format|
      format.csv do
        render :text => ProjectObservation.to_csv(@project.project_observations.all, :user => current_user)
      end
    end
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
    @place ||= Place.find_by_id(params[:place].to_i) || @places.try(:last)
    @default_taxa = @taxon ? @taxon.ancestors : Taxon::ICONIC_TAXA
    @taxon ||= Taxon::LIFE
    @default_taxa = [@default_taxa, @taxon].flatten.compact
  end

## Protected / private actions ###############################################
  private
  
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
    existing = photo_class.all(
      :include => :user,
      :conditions => ["native_photo_id IN (?)", photo_list.uniq]
    ).index_by{|p| p.native_photo_id}
    
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
          LocalPhoto.new(:file => photo_id, :user => current_user)
        else
          api_response ||= photo_class.get_api_response(photo_id, :user => current_user)
          if api_response
            photo_class.new_from_api_response(api_response, :user => current_user)
          end
        end
      end
      
      if photo.valid?
        photos << photo
      else
        logger.info "[INFO] #{current_user} tried to save an observation with an invalid photo (#{photo}): #{photo.errors.full_messages.to_sentence}"
      end
    end
    photos
  end
  
  # Processes params for observation requests.  Designed for use with 
  # will_paginate and standard observations query API
  def get_search_params(params)
    # The original params is important for things like pagination, so we 
    # leave it untouched.
    search_params = params.clone
    
    @swlat = search_params[:swlat] unless search_params[:swlat].blank?
    @swlng = search_params[:swlng] unless search_params[:swlng].blank?
    @nelat = search_params[:nelat] unless search_params[:nelat].blank?
    @nelng = search_params[:nelng] unless search_params[:nelng].blank?
    
    @q = search_params[:q].to_s unless search_params[:q].blank?
    if Observation::SPHINX_FIELD_NAMES.include?(search_params[:search_on])
      @search_on = search_params[:search_on]
    end
    
    find_options = {
      :include => [:user, {:taxon => [:taxon_names]}, :tags, :photos],
      :page => search_params[:page]
    }
    find_options[:page] = 1 if find_options[:page].to_i == 0
    find_options[:per_page] = @prefs["per_page"] if @prefs
    
    # Set format-based page sizes
    if request.format == :kml
      find_options.update(:limit => 100) if search_params[:limit].blank?
      find_options.update(:per_page => 100)
    elsif !search_params[:per_page].blank?
      find_options.update(:per_page => search_params[:per_page])
    elsif !search_params[:limit].blank?
      find_options.update(:per_page => search_params[:limit])
    end
    
    if find_options[:per_page] && find_options[:per_page].to_i > 200
      find_options[:per_page] = 200
    end
    
    if find_options[:limit] && find_options[:limit].to_i > 200
      find_options[:limit] = 200
    end
    
    find_options[:per_page] = 30 if find_options[:per_page].to_i == 0
    
    # iconic_taxa
    if search_params[:iconic_taxa]
      # split a string of names
      if search_params[:iconic_taxa].is_a? String
        search_params[:iconic_taxa] = search_params[:iconic_taxa].split(',')
      end
      
      # resolve taxa entered by name
      search_params[:iconic_taxa] = search_params[:iconic_taxa].map do |it|
        if it.to_i == 0
          Taxon.iconic_taxa.find_by_name(it)
        else
          Taxon.iconic_taxa.find_by_id(it)
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
        taxon_name_conditions[1] = Iconv.iconv('UTF8', 'LATIN1', @observations_taxon_name)
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
    
    if search_params[:order_by] && ORDER_BY_FIELDS.include?(search_params[:order_by])
      @order_by = search_params[:order_by]
      @order = if search_params[:order] && %w"asc desc".include?(search_params[:order].downcase)
        search_params[:order]
      else
        'desc'
      end
    else
      @order_by = "observations.id"
      @order = "desc"
    end
    search_params[:order_by] = "#{@order_by} #{@order}"
    
    # date
    date_pieces = [search_params[:year], search_params[:month], search_params[:day]]
    unless date_pieces.map{|d| d.blank? ? nil : d}.compact.blank?
      search_params[:on] = date_pieces.join('-')
    end
    if search_params[:on].to_s =~ /^\d{4}/
      @observed_on = search_params[:on]
      @observed_on_year, @observed_on_month, @observed_on_day = @observed_on.split('-').map{|d| d.to_i}
    end
    
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
      !@observed_on.blank?
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
    @observations ||= Observation.query(search_params).paginate(find_options)
    @observations
  rescue ThinkingSphinx::ConnectionError
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
      if request.format.html?
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
    
    # Sanitize query
    q = sanitize_sphinx_query(@q)
    
    # Field-specific searches
    if @search_on
      sphinx_options[:conditions] ||= {}
      # not sure why sphinx chokes on slashes when searching on attributes...
      sphinx_options[:conditions][@search_on.to_sym] = q.gsub(/\//, '')
      @observations = Observation.search(find_options.merge(sphinx_options))
    else
      @observations = Observation.search(q, find_options.merge(sphinx_options))
    end
    begin
      @observations.total_entries
    rescue ThinkingSphinx::SphinxError, Riddle::OutOfBoundsError => e
      Rails.logger.error "[ERROR #{Time.now}] Failed sphinx search: #{e}"
      @observations = WillPaginate::Collection.new(1,30, 0)
    end
    @observations
  rescue ThinkingSphinx::ConnectionError
    get_paginated_observations(search_params, find_options)
  end
  
  # Refresh lists affected by taxon changes in a batch of new/edited
  # observations.  Note that if you don't set @skip_refresh_lists on the records
  # in @observations before this is called, this won't do anything
  def refresh_lists_for_batch
    return true if @observations.blank?
    taxa = @observations.select(&:skip_refresh_lists).map(&:taxon).uniq.compact
    return true if taxa.blank?
    List.send_later(:refresh_for_user, current_user, :taxa => taxa.map(&:id))
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
      unless @observation.photos.detect {|p| p.native_photo_id == @facebook_photo.native_photo_id}
        @observation.photos[@observation.photos.size] = @facebook_photo
      end
      unless @observation.new_record?
        flash.now[:notice] = "<strong>Preview</strong> of synced observation.  " +
          "<a href=\"#{url_for}\">Undo?</a>"
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
      fp = flickr.photos.getInfo(:photo_id => params[:flickr_photo_id], 
        :auth_token => current_user.flickr_identity.token)
      @flickr_photo = FlickrPhoto.new_from_flickraw(fp, :user => current_user)
    rescue FlickRaw::FailedResponse => e
      logger.debug "[DEBUG] FlickRaw failed to find photo " +
        "#{params[:flickr_photo_id]}: #{e}\n#{e.backtrace.join("\n")}"
      @flickr_photo = nil
    rescue Timeout::Error => e
      flash.now[:error] = "Sorry, Flickr isn't responding at the moment."
      Rails.logger.error "[ERROR #{Time.now}] Timeout: #{e}"
      HoptoadNotifier.notify(e, :request => request, :session => session)
      return
    end
    if fp && @flickr_photo && @flickr_photo.valid?
      @flickr_observation = @flickr_photo.to_observation
      sync_attrs = %w(description species_guess taxon_id observed_on 
        observed_on_string latitude longitude place_guess)
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
      unless @observation.photos.detect {|p| p.native_photo_id == @flickr_photo.native_photo_id}
        @observation.photos[@observation.photos.size] = @flickr_photo
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
      HoptoadNotifier.notify(e, :request => request, :session => session)
      return
    end
    unless api_response
      logger.debug "[DEBUG] Failed to find Picasa photo for #{params[:picasa_photo_id]}"
      return
    end
    @picasa_photo = PicasaPhoto.new_from_api_response(api_response, :user => current_user)
    
    if @picasa_photo && @picasa_photo.valid?
      @picasa_observation = @picasa_photo.to_observation
      sync_attrs = [:description, :species_guess, :taxon_id, :observed_on,
        :observed_on_string, :latitude, :longitude, :place_guess]
      unless params[:picasa_sync_attrs].blank?
        sync_attrs = sync_attrs & params[:picasa_sync_attrs]
      end
      sync_attrs.each do |sync_attr|
        @observation.send("#{sync_attr}=", @picasa_observation.send(sync_attr))
      end
      
      unless @observation.photos.detect {|p| p.native_photo_id == @picasa_photo.native_photo_id}
        @observation.photos[@observation.photos.size] = @picasa_photo
      end
      
      flash.now[:notice] = "<strong>Preview</strong> of synced observation.  " +
        "<a href=\"#{url_for}\">Undo?</a>"
    else
      flash.now[:error] = "Sorry, we didn't find that photo."
    end
  end
  
  def load_photo_identities
    @photo_identities = Photo.descendent_classes.map do |klass|
      assoc_name = klass.to_s.underscore.split('_').first + "_identity"
      current_user.send(assoc_name) if current_user.respond_to?(assoc_name)
    end.compact
    
    reference_photo = @observation.try(:photos).try(:first)
    reference_photo ||= @observations.try(:first).try(:photos).try(:first)
    reference_photo ||= current_user.photos.last
    if reference_photo
      assoc_name = reference_photo.class.to_s.underscore.split('_').first + "_identity"
      @default_photo_identity = current_user.send(assoc_name) if current_user.respond_to?(assoc_name)
    end
    if params[:facebook_photo_id]
      @default_photo_identity = @photo_identities.detect{|pi| pi.to_s =~ /facebook/i}
    elsif params[:flickr_photo_id]
      @default_photo_identity = @photo_identities.detect{|pi| pi.to_s =~ /flickr/i}
    end
    @default_photo_identity ||= @photo_identities.first
    
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
  end
  
  def load_observation
    render_404 unless @observation = Observation.find_by_id(params[:id], 
      :include => [
        :photos, 
        {:taxon => [:taxon_names]},
        :identifications
      ]
    )
  end
  
  def require_owner
    unless logged_in? && current_user.id == @observation.user_id
      flash[:error] = "You don't have permission to do that"
      return redirect_to @observation
    end
  end
  
  def render_observations_to_csv(options = {})
    first = %w(scientific_name datetime description place_guess latitude longitude tag_list common_name url image_url user_login)
    only = (first + Observation.column_names).uniq
    except = %w(map_scale timeframe iconic_taxon_id delta geom)
    unless options[:show_private] == true
      except += %w(private_latitude private_longitude private_positional_accuracy)
    end
    only = only - except
    render :text => @observations.to_csv(:only => only.map{|c| c.to_sym})
  end
  
  def render_observations_to_kml(options = {})
    @net_hash = options
    if params[:kml_type] == "network_link"
      @net_hash = {
        :id => "AllObs", 
        :link_id =>"AllObs", 
        :snippet => "iNaturalist Feed for Everyone", 
        :description => "iNaturalist Feed for Everyone", 
        :name => "iNaturalist Feed for Everyone", 
        :href => "#{root_url}#{request.request_uri}".gsub(/kml_type=network_link/, '')
      }
      render :layout => false, :action => 'network_link'
      return
    end
    render :layout => false, :action => "index"
  end
  
  # create project observations if a project was specified and project allows 
  # auto-joining
  def create_project_observations
    return unless params[:project_id] && @project = Project.find_by_id(params[:project_id])
    @project_user = current_user.project_users.find_or_create_by_project_id(@project.id)
    return unless @project_user && @project_user.valid?
    errors = []
     @observations.each do |observation|
       po = @project.project_observations.build(:observation => observation)
       unless po.save
         errors = (errors + po.errors.full_messages).uniq
       end
     end
     
     unless errors.blank?
       flash[:error] = "Your observations couldn't be added to that " + 
         "project: #{errors.to_sentence}"
     end
  end
  
  def render_observations_partial(partial)
    if @observations.empty?
      render(:text => '')
    else
      render(:partial => partial, :collection => @observations, :layout => false)
    end
  end
end
