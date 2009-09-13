class ObservationsController < ApplicationController
  before_filter :load_user_by_login, :only => [:by_login]
  before_filter :login_required, 
                :except => [:explore,
                            :index,
                            :show,
                            :by_login,
                            :id_please,
                            :tile_points]
  before_filter :flickr_required, :only => [:import_flickr]
  cache_sweeper :observation_sweeper, :only => [:update, :destroy]
  before_filter :return_here, :only => [:index, :by_login, :show, :id_please]
  before_filter :limit_page_param_for_thinking_sphinx, :only => [:index, 
    :by_login]
  before_filter :curator_required, 
                  :only => [:curation]
  after_filter :refresh_lists_for_batch, :only => [:create, :update]
  
  caches_page :tile_points
  
  ORDER_BY_FIELDS = %w"place user created_at observed_on species_guess"
  REJECTED_FEED_PARAMS = %w"page view filters_open partial"
  REJECTED_KML_FEED_PARAMS = REJECTED_FEED_PARAMS + %w"swlat swlng nelat nelng"

  # GET /observations
  # GET /observations.xml
  def index
    @update = params[:update] # this is ONLY for RJS calls.  Lame.  Sorry.
    
    search_params, find_options = get_search_params(params)
    if search_params[:q]
      search_observations(search_params, find_options)
    else
      get_paginated_observations(search_params, find_options)
    end

    respond_to do |format|
      
      format.html do
        @iconic_taxa ||= []
        @view = params[:view] ||= 'map'
        if params[:partial]
          if @observations.empty?
            return render(:text => 'No observations matching those parameters.', 
              :status => 404)
          else
            return render(:partial => params[:partial], 
              :collection => @observations, :layout => false)
          end
        end
      end

      format.json do
        cache
        render :json => @observations.to_json({
          :include => {
            :user => {:only => :login},
            :flickr_photos => {}
          }
        })
      end
      
      format.atom do
        @updated_at = Observation.first(:order => 'updated_at DESC').updated_at
      end

      format.csv
      
      
      format.kml do
        if  params[:kml_type] == "network_link"
          if request.env['HTTP_USER_AGENT'].starts_with?("GoogleEarth")
            @net_hash = {
              :snippet => "iNaturalist Feed for Everyone", 
              :description => "iNaturalist Feed for Everyone", 
              :name => "iNaturalist Feed for Everyone"
            }
          else
            @net_hash = {
              :id => "BADLY FORMED LINK, Inform smcgregor08@cmc.edu if unexpected", 
              :link_id => "BADLY FORMED LINK, Inform smcgregor08@cmc.edu if unexpected", 
              :snippet => "BADLY FORMED LINK, Inform smcgregor08@cmc.edu if unexpected", 
              :description => "The link grabed was: " << (url_for(:controller => '/', :only_path=>false)),
              :name => "BADLY FORMED LINK, Inform smcgregor08@cmc.edu if unexpected", 
              :href => ""
            }
            render :action => 'network_link' and return
          end
        else #return the root network link
          @net_hash = {
            :id => "AllObs", 
            :link_id =>"AllObs", 
            :snippet => "iNaturalist Feed for Everyone", 
            :description => "iNaturalist Feed for Everyone", 
            :name => "iNaturalist Feed for Everyone", 
            :href => (url_for(:controller => '/', :only_path => false) << request.request_uri.from(1))
          }
          render :action => 'network_link' and return
        end
      end
      
    end
  end
  
  # GET /observations/1
  # GET /observations/1.xml
  def show
    @observation = Observation.find(params[:id], 
      :include => [
        :flickr_photos, 
        :markings, 
        {:taxon => [:taxon_names]},
        :identifications
      ]
    )

    if @observation.observed_on
      concurrent_observations = Observation.by(@observation.user).all(
        :conditions => ["observed_on < ? AND observed_on > ?", 
          @observation.observed_on + 1.day, 
          @observation.observed_on - 1.day],
        :order => "observed_on DESC, time_observed_at DESC",
        :include => [{:taxon => [:taxon_names]}]
      )
    else
      concurrent_observations = Observation.by(@observation.user).all(
        :conditions => "observed_on IS NULL",
        :order => "observed_on DESC, time_observed_at DESC",
        :include => [{:taxon => [:taxon_names]}]
      )
    end
    obs_pos = concurrent_observations.index(@observation)
    @previous = concurrent_observations[obs_pos+1]
    @next = concurrent_observations[obs_pos-1] if obs_pos != 0
    @previous ||= Observation.by(@observation.user).find(:first,
      :conditions => ["observed_on < ?", @observation.observed_on],
      :order => "observed_on DESC, time_observed_at DESC"
    )
    @next ||= Observation.by(@observation.user).find(:first,
      :conditions => ["observed_on > ?", @observation.observed_on],
      :order => "observed_on ASC, time_observed_at ASC"
    )
    
    # last lame condition: if next is still nil and observed_on is nil, then
    # we must be at the end of the dateless observations so grab the first 
    # dated one
    unless @observation.observed_on
      @next ||= Observation.by(@observation.user).find(:first,
        :conditions => "observed_on IS NOT NULL",
        :order => "observed_on ASC, time_observed_at ASC"
      )
    else
      @previous ||= Observation.by(@observation.user).find(:first,
        :conditions => "observed_on IS NULL",
        :order => "observed_on DESC, time_observed_at DESC"
      )
    end
    
    # b/c there were potenially many observations loaded above.  *hides face in shame*
    GC.start if concurrent_observations.size > 10
    
    respond_to do |format|
      format.html do
        # always display the time in the zone in which is was observed
        Time.zone = @observation.user.time_zone
                
        @identifications = @observation.identifications.all
        @owners_identification = @identifications.select do |ident|
          ident.user_id == @observation.user_id
        end.first
        if logged_in?
          @viewers_identification = @identifications.select do |ident|
            ident.user_id == current_user.id
          end.first
        end
        
        @identifications_by_taxon = @identifications.select do |ident|
          ident.user_id != ident.observation.user_id
        end.group_by(&:taxon)
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
        end
        
        @comments_and_identifications = (@observation.comments.all + 
          @identifications).sort_by(&:created_at)
        
        @marking_types = MarkingType.find(:all)
        
        if params[:partial]
          return render(:partial => params[:partial], :object => @observation,
            :layout => false)
        end
      end
       
      format.xml { render :xml => @observation }
      
      format.json do
        response.headers['Content-Type'] = 'text/plain; charset=utf-8'
        render :json => @observation.to_json
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
    if params[:taxon_id] && taxon = Taxon.find_by_id(params[:taxon_id])
      options[:taxon] = taxon
      if common_name = taxon.common_name
        options[:species_guess] = taxon.common_name.name
      else 
        options[:species_guess] = taxon.name
      end
    end
    options[:time_zone] = current_user.time_zone
    [:latitude, :longitude, :place_guess, :location_is_exact].each do |obs_attr|
      options[obs_attr] ||= params[obs_attr]
    end
    @observation = Observation.new(options)
    
    respond_to do |format|
      format.html do
        @observations = [@observation]
      end

      # for a resource request, return a single observation
      format.xml  { render :xml => @observation }
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
    @observation = Observation.find(params[:id])
    
    # Only the owner should be able to see this.  
    unless current_user.id == @observation.user_id or current_user.is_admin?
      redirect_to observation_path(@observation)
    end
  end

  # POST /observations
  # POST /observations.xml
  def create
    # Handle the case of a single obs
    params[:observations] = [[0, params[:observation]]] if params[:observation]
    
    @observations = params[:observations].map do |fieldset_index, observation|
      observation.delete('fieldset_index') if observation[:fieldset_index]
      o = Observation.new(observation)
      o.user = current_user
      
      # Get Flickr photos
      if params[:flickr_photos] && params[:flickr_photos][fieldset_index]
        o.flickr_photos << retreive_flickr_photos(
          params[:flickr_photos][fieldset_index], {:user => current_user})
      end
      
      # Skip list updates (to be performed in an after_filter)
      o.skip_refresh_lists = true
      
      o
    end
    
    self.current_user.observations << @observations
    
    # check for errors
    errors = false
    @observations.each { |obs| errors = true unless obs.valid? }
    respond_to do |format|
      format.html do
        unless errors
          flash[:notice] = params[:success_msg] || "Observation(s) saved!"
          if params[:commit] == "Save and add another"
            redirect_to :action => 'new'
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
      format.json { render :json => @observations.to_json }
    end
  end

  # PUT /observations/1
  # PUT /observations/1.xml
  def update
    
    observation_user = current_user
    
    unless params[:admin_action].nil? or !current_user.is_admin?
      observation_user = Observation.find(params[:id]).user
    end
    
    # Handle the case of a single obs
    params[:observations] = [[params[:id], params[:observation]]] if params[:observation]
    
    @observations = Observation.all(
      :conditions => [
        "id IN (?) AND user_id = ?", 
        params[:observations].map(&:first),
        observation_user
      ]
    )
    
    # Convert the params to a hash keyed by ID.  Yes, it's weird
    hashed_params = Hash[*params[:observations].to_a.flatten]
    errors = false
    @observations.each do |observation|      
      # Update the flickr photos
      # Note: this ignore photos thing is a total hack and should only be
      # included if you are updating observations but aren't including flickr
      # fields, e.g. when removing something from ID please
      unless params[:ignore_photos]
        if params[:flickr_photos] && params[:flickr_photos][observation.id.to_s]
          observation.flickr_photos = retreive_flickr_photos(
            params[:flickr_photos][observation.id.to_s], 
            {:user => observation_user})
        else
          observation.flickr_photos.clear
        end
      end
      
      # Skip list updates (to be performed in an after_filter)
      observation.skip_refresh_lists = true
      
      unless observation.update_attributes(hashed_params[observation.id.to_s])
        errors = true
      end
    end

    respond_to do |format|
      unless errors
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
      else
        format.html do
          if @observations.size == 1
            @observation = @observations.first
            render :action => 'edit'
          else
            render :action => 'edit_batch'
          end
        end
        format.xml  { render :xml => @observation.errors, :status => :unprocessable_entity }
      end
    end
  end
  
  # DELETE /observations/1
  # DELETE /observations/1.xml
  def destroy
    @observation = Observation.find(params[:id])
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
          :taxon => Taxon.find(
            :first, 
            :include => :taxon_names, 
            :conditions => ["taxon_names.name = ?", taxon_name_str.strip]),
          :place_guess => params[:batch][:place_guess],
          :longitude => longitude,
          :latitude => latitude,
          :map_scale => params[:batch][:map_scale],
          :location_is_exact => params[:batch][:location_is_exact],
          :observed_on_string => params[:batch][:observed_on_string],
          :time_zone => current_user.time_zone)
      end
      @step = 2
    end
    render :layout => 'observations/batch'
  end


  def new_batch_csv
    require "csv"

    if params[:upload] && params[:upload][:datafile]
      @observations = []
      @hasInvalid = false
      csv = params[:upload][:datafile].to_tempfile
      max_rows = 100
      row_num = 0
      
      begin
        CSV::Reader.parse(csv) do |row|
          if row[0] or row[1] or row[2] or row[3] or row[4] or row[5]
            obsHash = {:user => current_user,
            :species_guess => row[0],
            :taxon => Taxon.find(
              :first, 
              :include => :taxon_names, 
              :conditions => ["taxon_names.name = ?", row[0]]),
            :observed_on_string => row[1],
            :description => row[2],
            :place_guess => row[3],
            :time_zone => current_user.time_zone}
            if(row[4] && row[5]) 
              obsHash.update(:latitude=>row[4], :longitude=>row[5], :location_is_exact=>true)
            elsif row[3]
              places = Ym4r::GmPlugin::Geocoding.get(row[3])
              unless places.empty?
                latitude = places.first.latitude
                longitude = places.first.longitude
                obsHash.update(:latitude=>latitude, :longitude=>longitude, :location_is_exact=>false)
              end
            end
            obs = Observation.new(obsHash)
            obs.tag_list = row[6]
           @hasInvalid ||= !obs.valid?
           @observations << obs
           row_num += 1
          end
          if row_num >= max_rows
            flash[:notice] = "You have a beehive of observations!<br /> We can only take your first #{max_rows} observations in every CSV"
            break
          end
        end
      rescue CSV::IllegalFormatError
        flash[:error] = "Your CSV returned an illegal format exception. If the problem persists after you remove any strange characters, please email us the file and we'll figure out the problem"
        render :contoller => 'observations', :action => 'import'
        return
      end
    end
    render :layout => 'observations/batch'
  end

  # Edit a batch of observations
  def edit_batch
    @observations = Observation.find(:all, 
      :conditions => [
        "id in (?) AND user_id = ?", params[:o].split(','), current_user])
  end
  
  def delete_batch
    @observations = Observation.find(:all, 
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
  
  def import_flickr
    photos = retreive_flickr_photos(
      params[:flickr_photos], {:user => current_user})
    @observations = photos.map do |photo|
      photo.to_observation
    end
    @step = 2
    render :layout => 'observations/batch', :template => 'observations/new_batch'
  end

  # gets observations by user login
  def by_login
    search_params, find_options = get_search_params(params)
    search_params.update(:user_id => @selected_user.id)
    find_options[:per_page] = 10 if request.format == :html
    if search_params[:q]
      search_observations(search_params, find_options)
    else
      get_paginated_observations(search_params, find_options)
    end
    
    respond_to do |format|
      format.html
      
      format.kml do
        user = @login.to_s
        if request.env['HTTP_USER_AGENT'].starts_with?("GoogleEarth") and params[:kml_type] == "network_link"

          if params[:kml_type] == "network_link"
            @net_hash = {
              :snippet=>"iNaturalist Feed for User:"<<user, 
              :description=>"iNaturalist Feed for User:"<<user, 
              :name=>"iNaturalist Feed for User:"<<user
            }

          else
            @net_hash = {
              :id => "BADLY FORMED LINK, Inform smcgregor08@cmc.edu if unexpected", 
              :link_id => "BADLY FORMED LINK, Inform smcgregor08@cmc.edu if unexpected", 
              :snippet => "BADLY FORMED LINK, Inform smcgregor08@cmc.edu if unexpected", 
              :description => "The link grabed was: "<<(url_for(:controller => '/', :only_path=>false)), 
              :name => "BADLY FORMED LINK, Inform smcgregor08@cmc.edu if unexpected", 
              :href => ""
            }
            render :action => 'network_link' and return
          end

        else #return the root network link
          @net_hash = {
            :id => "User" << user, 
            :link_id => "UserLink" << user, 
            :snippet => "iNaturalist Feed for User:" << user, 
            :description => "iNaturalist Feed for User:" << user, 
            :name => "iNaturalist Feed for User:" << user, 
            :href => (url_for(:controller => '/', :only_path => false) << request.request_uri.from(1))
          }
          render :action => 'network_link' and return
        end
      end

      format.atom
      format.csv
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
        :flickr_photos, 
        {:identifications => [{:taxon => [:taxon_names]}, :user]}, 
        {:comments => [:user]}
      ]
    )
    if search_params[:has]
      search_params[:has] = (search_params[:has].split(',') + 'id_please').uniq
    else
      search_params[:has] = 'id_please'
    end
    
    search_observations(search_params, find_options)
    
    @top_identifiers = User.all(:order => "identifications_count DESC", 
      :limit => 5)
  end

  #
  # Add markings.  Note that this is a function which adds social markings not
  # map based markings. It should redirect or return a JSON response on
  # successful completetion.
  #
  def add_marking
    @observation = Observation.find(params[:id])
    respond_to do |format|
      if @observation.mark(@user.id, params[:marking_type_id])
        format.html { redirect_to @observation }
        format.json { render :json => @observation.markings.pop.to_json }
      else
        # something went wrong
        marking_with_error = @observation.markings.pop
        format.html {
          if marking_with_error.errors.on(:marking_type_id)
            flash[:notice] = marking_with_error.errors.on(:marking_type_id)
          else
            flash[:notice] = "Your marking could not be accepted, try again later."
          end
          redirect_to @observation
        }
        format.json   { render :json => marking_with_error.errors, 
                               :status => :unprocessable_entity }
      end
    end
  end
  
  def remove_marking
    @observation = Observation.find(params[:id])
    
    # Returns the destroyed marking or false if no marking could be found
    marking = @observation.unmark(@user.id, params[:marking_type_id])
    
    respond_to do |format|
      if marking
        format.html { redirect_to @observation }
        format.json { render :json => marking.to_json }
      else
        # something went wrong
        format.html {
          flash[:notice] = "We could not unset a marking that doesn't exist!"
          redirect_to @observation
        }
        format.json   { render :json => [['marking_type_id',
                                           'Could not be found.']], 
                               :status => :unprocessable_entity }
      end
    end
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
      :select => "id, species_guess, latitude, longitude, user_id, description",
      :include => [:user, :flickr_photos], :limit => 500, :order => "id DESC")
    
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

## Protected / private actions ###############################################
  private
  
  def retreive_flickr_photos(photo_list=nil, options = {})
    return [] if photo_list.blank?
    photo_list = [photo_list] unless photo_list.is_a? Array
    
    # simple algorithm,
    # 1. create an array to be passed back to the observation obj
    # 2. check to see if that flickr photo's data has already been stored
    # 3. if yes
    #      retreive flickrPhoto obj and put in array
    #    if no
    #      create flickrPhoto obj and put in array
    # 4. return array
    flickr = get_net_flickr
    flickr.auth.token = @user.flickr_identity.token
    photos = []
    existing = FlickrPhoto.all(
      :include => :user,
      :conditions => ["flickr_native_photo_id IN (?)", photo_list.uniq]
    ).index_by(&:flickr_native_photo_id)
    
    photo_list.uniq.each do |photo_id|
      flickr_photo = existing[photo_id]
      
      if options[:sync] || flickr_photo.nil?
        fp = flickr.photos.get_info(photo_id)
      end
      
      # Sync existing if called for
      if options[:sync] && flickr_photo
        # sync the photo URLs b/c they change when photos become private
        flickr_photo.user ||= options[:user]
        flickr_photo.flickr_response = fp # set to make sure user validation works
        flickr_photo.sync
        flickr_photo.save if flickr_photo.changed?
      end
      
      # Create a new one if one doesn't already exist
      unless flickr_photo
        flickr_photo = FlickrPhoto.new_from_net_flickr(fp, 
          :user => current_user)
      end
      
      if flickr_photo.valid?
        photos << flickr_photo 
      else
        logger.info "[INFO] #{current_user} tried to save an observation " +
          "with a flickr photo (#{flickr_photo}) that wasn't their own."
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
    
    @filters_open = search_params[:filters_open] == 'true'
    
    @q = search_params[:q] unless search_params[:q].blank?
    @search_on = search_params[:search_on] unless search_params[:search_on].blank?
    
    find_options = {
      :include => [:user, {:taxon => [:taxon_names]}, :tags, :flickr_photos],
      :page => search_params[:page] || 1
    }
    
    # Set format-based page sizes
    if request.format == :csv
      find_options.update(:per_page => 2000)
    elsif request.format == :kml
      find_options.update(:limit => 100) if search_params[:limit].blank?
      find_options.update(:per_page => 100)
    elsif !search_params[:per_page].blank?
      find_options.update(:per_page => search_params[:per_page])
    elsif !search_params[:limit].blank?
      find_options.update(:per_page => search_params[:limit])
    else
      find_options.update(:per_page => 30)
    end
    
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
    
    if search_params[:has]
      if search_params[:has].is_a?(String)
        search_params[:has] = search_params[:has].split(',')
      end
      @id_please = true if search_params[:has].include?('id_please')
      @with_photos = true if search_params[:has].include?('photos')
    end
    
    @identifications = search_params[:identifications]
    
    if search_params[:order_by] && 
       ORDER_BY_FIELDS.include?(search_params[:order_by])
      @order_by = search_params[:order_by]
      if search_params[:order] && 
         %w"asc desc".include?(search_params[:order].downcase)
        @order = search_params[:order]
      else
        @order = 'desc'
      end
      search_params[:order_by] = "#{@order_by} #{@order}"
    else
      search_params[:order_by] = 'observed_on DESC'
    end
    
    [search_params, find_options]
  end
  
  # Either make a plain db query and return a WillPaginate collection or make 
  # a Sphinx call if there were query terms specified.
  def get_paginated_observations(search_params, find_options)
    if @q
      if @search_on
        find_options[:conditions] = update_conditions(
          find_options[:conditions], @search_on.to_sym => @q
        )
        @observations = Observation.query(search_params).search(
          find_options).compact
      else
        @observations = Observation.query(search_params).search(
          @q, find_options).compact
      end
    else
      @observations = Observation.query(search_params).paginate(find_options)
    end
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
    sphinx_options[:conditions] = {}
    
    if search_params[:has]
      # id please
      if search_params[:has].include?('id_please')
        sphinx_options[:conditions][:has_id_please] = true
      end
      
      # has photos
      if search_params[:has].include?('photos')
        sphinx_options[:conditions][:has_photos] = true
      end
      
      # geo
      if search_params[:has].include?('geo')
        sphinx_options[:conditions][:has_geo] = true 
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
        sphinx_options[:conditions][:longitude] = lngrange
        # sphinx_options[:conditions][:longitude] = swlngrads..Math::PI
        # sphinx_options[:with] = {:longitude => -Math::PI..nelngrads}
      else
        sphinx_options[:conditions][:longitude] = swlngrads..nelngrads
      end
      sphinx_options[:conditions][:latitude] = swlatrads..nelatrads
    elsif (search_params[:lat] and search_params[:lng])
      latrads = search_params[:lat].to_f * (Math::PI / 180)
      lngrads = search_params[:lng].to_f * (Math::PI / 180)
      sphinx_options[:geo] = [latrads, lngrads]
      sphinx_options[:order] = "@geodist asc"
    end
    
    # identifications
    case search_params[:identifications]
    when 'most_agree'
      sphinx_options[:conditions][:identifications_most_agree] = true
    when 'some_agree'
      sphinx_options[:conditions][:identifications_some_agree] = true
    when 'most_disagree'
      sphinx_options[:conditions][:identifications_most_disagree] = true
    end
    
    # Taxon ID
    if search_params[:taxon_id]
      sphinx_options[:conditions][:taxon_id] = search_params[:taxon_id]
    end
    
    # Iconic taxa
    if search_params[:iconic_taxa]
      sphinx_options[:conditions][:iconic_taxon_id] = \
          search_params[:iconic_taxa].map do |iconic_taxon|
        iconic_taxon.nil? ? nil : iconic_taxon.id
      end
    end
    
    # User ID
    if search_params[:user_id]
      sphinx_options[:conditions][:user_id] = search_params[:user_id]
    end
    
    # User login
    if search_params[:user]
      sphinx_options[:conditions][:user] = search_params[:user]
    end
    
    # Ordering
    if search_params[:order_by]
      if sphinx_options[:order]
        sphinx_options[:order] += ", #{search_params[:order_by]}"
      else
        sphinx_options[:order] = search_params[:order_by]
      end
    end
    
    # Field-specific searches
    if @search_on
      sphinx_options[:conditions][@search_on.to_sym] = @q
      @observations = Observation.search(find_options.merge(sphinx_options))
    else
      @observations = Observation.search(@q, 
        find_options.merge(sphinx_options))
    end
  rescue ThinkingSphinx::ConnectionError
    get_paginated_observations(search_params, find_options)
  end
  
  # Refresh lists affected by taxon changes in a batch of new/edited
  # observations.  Note that if you don't set @skip_refresh_lists on the records
  # in @observations before this is called, this won't do anything
  def refresh_lists_for_batch
    taxa = @observations.select(&:skip_refresh_lists).map(&:taxon).uniq.compact
    return true if taxa.blank?
    spawn(:nice => 7) do
      List.refresh_for_user(current_user, :taxa => taxa)
    end
  end
end
