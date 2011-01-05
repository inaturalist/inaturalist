class ObservationsController < ApplicationController
  before_filter :load_user_by_login, :only => [:by_login]
  before_filter :login_required, 
                :except => [:explore,
                            :index,
                            :show,
                            :by_login,
                            :id_please,
                            :tile_points,
                            :nearby,
                            :widget]
  cache_sweeper :observation_sweeper, :only => [:update, :destroy]
  before_filter :load_observation, :only => [:show, :edit, :edit_photos, 
    :update_photos, :destroy]
  before_filter :require_owner, :only => [:edit, :edit_photos, 
    :update_photos]
  before_filter :return_here, :only => [:index, :by_login, :show, :id_please, 
    :import, :add_from_list]
  before_filter :limit_page_param_for_thinking_sphinx, :only => [:index, 
    :by_login]
  before_filter :curator_required, :only => [:curation]
  before_filter :load_photo_identities, :only => [:new, :new_batch, :edit,
    :edit_batch, :import, :import_photos, :new_from_list]
  before_filter :photo_identities_required, :only => [:import_photos]
  after_filter :refresh_lists_for_batch, :only => [:create, :update]
  
  MOBILIZED = [:add_from_list, :nearby, :add_nearby]
  before_filter :unmobilized, :except => MOBILIZED
  before_filter :mobilized, :only => MOBILIZED
  
  
  caches_page :tile_points
  
  ORDER_BY_FIELDS = %w"place user created_at observed_on species_guess"
  REJECTED_FEED_PARAMS = %w"page view filters_open partial"
  REJECTED_KML_FEED_PARAMS = REJECTED_FEED_PARAMS + %w"swlat swlng nelat nelng"

  # GET /observations
  # GET /observations.xml
  def index
    @update = params[:update] # this is ONLY for RJS calls.  Lame.  Sorry.
    
    search_params, find_options = get_search_params(params)
    if search_params[:q].blank?
      get_paginated_observations(search_params, find_options)
    else
      search_observations(search_params, find_options)
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
        unless params[:partial].blank?
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
            item[:html] = render_to_string(:partial => params[:partial], :object => observation)
            @template.template_format = :json
            item
          end
          render :json => data
        else
          render :json => @observations.to_json({
            :include => {
              :user => {:only => :login},
              :photos => {}
            }
          })
        end
      end
      
      format.atom do
        @updated_at = Observation.first(:order => 'updated_at DESC').updated_at
      end

      format.csv do
        render_observations_to_csv
      end
      
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
            render :layout => false, :action => 'network_link' and return
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
          render :layout => false, :action => 'network_link' and return
        end
        render :layout => false
      end
      
      format.widget do
        render :js => render_to_string(:partial => "widget.js.erb", :locals => {
          :show_user => true
        })
      end
    end
  end
  
  # GET /observations/1
  # GET /observations/1.xml
  def show

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
          
          @project_users = current_user.project_users.all(:include => :project)
          @project_observations = @observation.project_observations.all
          @project_observations_by_project_id = @project_observations.index_by(&:project_id)
        end
        
        @comments_and_identifications = (@observation.comments.all + 
          @identifications).sort_by(&:created_at)
        
        # @marking_types = MarkingType.find(:all)
        
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
    if !params[:taxon_id].blank? && (taxon = Taxon.find_by_id(params[:taxon_id]))
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
    
    sync_flickr_photo if params[:flickr_photo_id]
    sync_picasa_photo if params[:picasa_photo_id]
    
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
    
    sync_flickr_photo if params[:flickr_photo_id]
    sync_picasa_photo if params[:picasa_photo_id]
  end

  # POST /observations
  # POST /observations.xml
  def create
    # Handle the case of a single obs
    params[:observations] = [['0', params[:observation]]] if params[:observation]
    
    @observations = params[:observations].map do |fieldset_index, observation|
      observation.delete('fieldset_index') if observation[:fieldset_index]
      o = Observation.new(observation)
      o.user = current_user
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
    
    unless params[:admin_action].nil? || !current_user.is_admin?
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
    
    # Make sure there's no evil going on
    unique_user_ids = @observations.map(&:user_id).uniq
    if unique_user_ids.size > 1 || unique_user_ids.first != observation_user.id
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
  end


  def new_batch_csv
    require "csv"
    
    if params[:upload].blank? || params[:upload] && params[:upload][:datafile].blank?
      flash[:error] = "You must select a CSV file to upload."
      return redirect_to :action => "import"
    end

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
            obsHash.update(:latitude => row[4], :longitude => row[5], :location_is_exact => true)
          elsif row[3]
            places = Ym4r::GmPlugin::Geocoding.get(row[3])
            unless places.empty?
              latitude = places.first.latitude
              longitude = places.first.longitude
              obsHash.update(:latitude => latitude, :longitude => longitude, :location_is_exact => false)
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
      flash[:error] = <<-EOT
        Your CSV had a formatting problem. Try removing any strange
        characters, and if the problem persists, please
        <a href="mailto:help@inaturalist.org">email us</a> the file and we'll
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
    @observations = photos.map(&:to_observation)
    @observation_photos = ObservationPhoto.all(
      :conditions => ["photos.native_photo_id IN (?)", photos.map(&:native_photo_id)],
      :include => [:photo, :observation]
    )
    @step = 2
    render :template => 'observations/new_batch'
  end
  
  def add_from_list
    @order = params[:order] || "alphabetical"
    if @list = List.find_by_id(params[:id])
      @cache_key = {:controller => "observations", :action => "add_from_list", :id => @list.id, :order => @order}
      unless fragment_exist?(@cache_key)
        @listed_taxa = @list.listed_taxa.order_by(@order).all(:include => {:taxon => [:photos, :taxon_names]})
        @listed_taxa_alphabetical = @listed_taxa.sort! {|a,b| a.taxon.default_name.name <=> b.taxon.default_name.name}
        @listed_taxa = @listed_taxa_alphabetical if @order == ListedTaxon::ALPHABETICAL_ORDER
        @taxon_ids_by_name = {}
        ancestor_ids = @listed_taxa.map{|lt| lt.taxon_ancestor_ids.split(',')}.flatten.uniq
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
        :species_guess => taxon.default_name.name)
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
          @project_users = current_user.project_users.all(:include => :project)
        end
      end
      
      format.kml do
        user = @login.to_s
        if request.env['HTTP_USER_AGENT'].starts_with?("GoogleEarth") && params[:kml_type] == "network_link"

          if params[:kml_type] == "network_link"
            @net_hash = {
              :snippet=>"iNaturalist Feed for User:" << user,
              :description=>"iNaturalist Feed for User:" << user,
              :name=>"iNaturalist Feed for User:" << user
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
            render :layout => false, :action => 'network_link' and return
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
          render :layout => false, :action => 'network_link' and return
        end
      end

      format.atom
      format.csv { render_observations_to_csv }
      format.widget do
        render :js => render_to_string(:partial => "widget.js.erb")
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
      search_params[:has] = (search_params[:has].split(',') + 'id_please').uniq
    else
      search_params[:has] = 'id_please'
    end
    
    search_observations(search_params, find_options)
    
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
      :select => "id, species_guess, latitude, longitude, user_id, description",
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
    @place = Place.find_by_id(params[:place_id]) if params[:place_id]
    @order_by = params[:order_by] || "observed_on"
    @order = params[:order] || "desc"
    @limit = params[:limit] || 5
    @limit = @limit.to_i
    if %w"logo-small.gif logo-small.png logo-small-white.png none".include?(params[:logo])
      @logo = params[:logo] 
    end
    @logo ||= "logo-small.gif"
    url_params = {
      :format => "widget", 
      :limit => @limit, 
      :order => @order, 
      :order_by => @order_by
    }
    @widget_url = if @place
      observations_url(url_params.merge(:place_id => @place.id))
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
    # Geocoding IP until I figure out getting loc from iphone
    ip = request.remote_ip
    # ip = '66.117.138.26' # Emeryville IP, for testing
    if GEOIP && (@geoip_result = GeoipTools.city(ip)) && 
        !@geoip_result[:latitude].blank? && @geoip_result[:latitude] <= 180
      @lat = @geoip_result[:latitude]
      @lon = @geoip_result[:longitude]
      @city = @geoip_result[:city]
      @state_code = @geoip_result[:state_code]
      @place_name = "#{@city}, #{@state_code}" unless @city.blank? || @state_code.blank?
      @latrads = @lat.to_f * (Math::PI / 180)
      @lonrads = @lon.to_f * (Math::PI / 180)
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
    @observation = Observation.new
    respond_to do |format|
      format.mobile
    end
  end
  
  def project
    unless @project = Project.find_by_id(params[:id])
      flash[:error] = "That project doesn't exist."
      redirect_to :back and return
    end
    
    search_params, find_options = get_search_params(params)
    search_params[:projects] = @project.id
    if search_params[:q].blank?
      get_paginated_observations(search_params, find_options)
    else
      search_observations(search_params, find_options)
    end
    
    respond_to do |format|
      format.html
      format.atom do
        @updated_at = Observation.first(:order => 'updated_at DESC').updated_at
        render :action => "index"
      end
      format.csv { render_observations_to_csv }
      format.kml do
        @net_hash = {
          :snippet => "#{@project.title.html_safe} Observations", 
          :description => "Observations feed for the iNaturalist project '#{@project.title.html_safe}'", 
          :name => "#{@project.title.html_safe} Observations"
        }
        render :layout => false, :action => "index"
      end
    end
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
    ).index_by(&:native_photo_id)
    
    photo_list.uniq.each do |photo_id|
      if (photo = existing[photo_id]) || options[:sync]
        api_response = photo_class.get_api_response(photo_id, :user => current_user)
      end
      
      # Sync existing if called for
      if options[:sync] && photo
        # sync the photo URLs b/c they change when photos become private
        photo.user ||= options[:user]
        photo.api_response = api_response # set to make sure user validation works
        photo.sync
        photo.save if photo.changed?
      end
      
      # Create a new one if one doesn't already exist
      unless photo
        api_response ||= photo_class.get_api_response(photo_id, :user => current_user)
        unless photo = photo_class.new_from_api_response(api_response, :user => current_user)
          photo = LocalPhoto.new(:file => photo_id, :user => current_user)
        end
      end
      
      if photo.valid?
        photos << photo
      else
        logger.info "[INFO] #{current_user} tried to save an observation " +
          "with an invalid photo (#{photo}): " + photo.errors.full_messages.to_sentence
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
    
    @q = search_params[:q] unless search_params[:q].blank?
    @search_on = search_params[:search_on] unless search_params[:search_on].blank?
    
    @filters_open = !@q.nil?
    @filters_open = search_params[:filters_open] == 'true' if search_params.has_key?(:filters_open)
    
    find_options = {
      :include => [:user, {:taxon => [:taxon_names]}, :tags, :photos],
      :page => search_params[:page] || 1
    }
    find_options[:per_page] = @prefs.per_page if @prefs
    
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
    
    if search_params[:order_by] && ORDER_BY_FIELDS.include?(search_params[:order_by])
      @order_by = search_params[:order_by]
      @order = if search_params[:order] && %w"asc desc".include?(search_params[:order].downcase)
        search_params[:order]
      else
        'desc'
      end
      search_params[:order_by] = "#{@order_by} #{@order}"
    else
      @order_by = "observed_on"
      @order = "desc"
    end
    search_params[:order_by] = "#{@order_by} #{@order}"
    
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
    if search_params[:taxon_id]
      sphinx_options[:with][:taxon_id] = search_params[:taxon_id]
    end
    
    # Iconic taxa
    if search_params[:iconic_taxa]
      sphinx_options[:with][:iconic_taxon_id] = \
          search_params[:iconic_taxa].map do |iconic_taxon|
        iconic_taxon.nil? ? nil : iconic_taxon.id
      end
    end
    
    # User ID
    if search_params[:user_id]
      sphinx_options[:with][:user_id] = search_params[:user_id]
    end
    
    # User login
    if search_params[:user]
      sphinx_options[:with][:user] = search_params[:user]
    end
    
    # Ordering
    if search_params[:order_by]
      if sphinx_options[:order]
        sphinx_options[:order] += ", #{search_params[:order_by]}"
        sphinx_options[:sort_mode] = :extended
      elsif search_params[:order_by] =~ /\sdesc|asc/i
        sphinx_options[:order] = search_params[:order_by].split.first.to_sym
        sphinx_options[:sort_mode] = search_params[:order_by].split.last.downcase.to_sym
      else
        sphinx_options[:order] = search_params[:order_by].to_sym
      end
    end
    
    if search_params[:projects]
      sphinx_options[:with][:projects] = if search_params[:projects].is_a?(String) && search_params[:projects].index(',')
        search_params[:projects].split(',')
      else
        [search_params[:projects]].flatten
      end
    end
    
    # Field-specific searches
    if @search_on
      sphinx_options[:conditions] ||= {}
      sphinx_options[:conditions][@search_on.to_sym] = @q
      @observations = Observation.search(find_options.merge(sphinx_options))
    else
      @observations = Observation.search(@q, find_options.merge(sphinx_options))
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
    List.send_later(:refresh_for_user, current_user, :taxa => taxa.map(&:id))
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
      sync_attrs = [:description, :species_guess, :taxon_id, :observed_on, 
        :observed_on_string, :latitude, :longitude, :place_guess]
      unless params[:flickr_sync_attrs].blank?
        sync_attrs = sync_attrs & params[:flickr_sync_attrs]
      end
      sync_attrs.each do |sync_attr|
        @observation.send("#{sync_attr}=", @flickr_observation.send(sync_attr))
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
      klass_name = klass.to_s.underscore.split('_').first + "_identity"
      current_user.send(klass_name) if current_user.respond_to?(klass_name)
    end.compact
    
    first = if @observation
      @observation.photos.first
    elsif !@observations.blank?
      @observations.first.photos.first
    else
      nil
    end
    
    if first
      @default_photo_identity = case first.class.to_s
      when 'FlickrPhoto'
        @photo_identities.detect{|pi| pi.is_a?(FlickrIdentity)}
      when 'PicasaPhoto'
        @photo_identities.detect{|pi| pi.is_a?(PicasaIdentity)}
      end
    else
      @default_photo_identity = @photo_identities.first
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
      flash[:error] = "You don't have permission to edit that observation."
      return redirect_to @observation
    end
  end
  
  def render_observations_to_csv
    render :text => @observations.to_csv(
      :methods => [:scientific_name, :common_name, :url, :image_url, :tag_list, :user_login],
      :except => [:map_scale, :timeframe, :iconic_taxon_id, :delta]
    )
  end
end
