class ProjectsController < ApplicationController
  WIDGET_CACHE_EXPIRATION = 15.minutes

  protect_from_forgery unless: -> { request.format.widget? }
  before_filter :allow_external_iframes, only: [:show]

  caches_action :observed_taxa_count, :contributors,
    :expires_in => WIDGET_CACHE_EXPIRATION,
    :cache_path => Proc.new {|c| c.params}, 
    :if => Proc.new {|c| c.request.format == :widget}

  before_action :doorkeeper_authorize!, 
    only: [ :by_login, :join, :leave, :members ],
    if: lambda { authenticate_with_oauth? }
  
  before_filter :return_here, :only => [:index, :show, :contributors, :members, :show_contributor, :terms, :invite]
  before_filter :authenticate_user!, 
    :unless => lambda { authenticated_with_oauth? },
    :except => [ :index, :show, :search, :map, :contributors, :observed_taxa_count,
      :browse, :calendar, :stats_slideshow ]
  load_except = [ :create, :index, :search, :new_traditional, :by_login, :map, :browse, :calendar, :new ]
  before_filter :load_project, :except => load_except
  blocks_spam :except => load_except, :instance => :project
  before_filter :ensure_current_project_url, :only => :show
  before_filter :load_project_user, :except => [:index, :search, :new_traditional, :by_login, :new]
  before_filter :load_user_by_login, :only => [:by_login]
  before_filter :ensure_can_edit, :only => [:edit, :update]
  before_filter :filter_params, :only => [:update, :create]
  
  ORDERS = %w(title created)
  ORDER_CLAUSES = {
    'title' => 'lower(title)',
    'created' => 'id'
  }

  def index
    respond_to do |format|
      format.html do
        if @site && (@site_place = @site.place)
          @place = @site.place unless params[:everywhere].yesish?
        end
        @projects = Project.recently_added_to(place: @place)
        @created = Project.not_flagged_as_spam.order("projects.id desc").limit(8)
        @created = @created.joins(:place).where(@place.self_and_descendant_conditions) if @place
        @featured = Project.featured
        @featured = @featured.joins(:place).where(@place.self_and_descendant_conditions) if @place
        @carousel = @featured.where( "project_type IN ('collection', 'umbrella')" ).limit( 3 )
        @carousel = @featured.limit( 3 ) if @carousel.count == 0
        @carousel = @projects.limit( 3 ) if @carousel.count == 0

        # Temporary for CNC
        if cnc_project = Project.find( "city-nature-challenge-2018" ) rescue nil
          @carousel = [cnc_project, @carousel.to_a].flatten.uniq[0..3]
        end

        @featured = @featured.limit( 30 ).to_a.reject{ |p| @carousel.include?( p )}[0..8]
        @recent = Project.joins(:posts).order( "posts.id DESC" ).limit( 20 )
        @recent = @recent.joins( :place ).where( @place.self_and_descendant_conditions ) if @place
        @recent = @recent.to_a.uniq[0..8]
        if logged_in?
          @started = current_user.projects.not_flagged_as_spam.
            order("projects.id desc").limit(5)
          @joined = current_user.project_users.joins(:project).
            merge(Project.not_flagged_as_spam).includes(:project).
            where( "projects.user_id != ?", current_user ).
            order("projects.id desc").limit(5).map(&:project)
          @followed = Project.
            joins( "JOIN subscriptions ON subscriptions.resource_type = 'Project' AND resource_id = projects.id" ).
            where( "subscriptions.user_id = ?", current_user ).
            where( "projects.user_id != ?", current_user ).
            order( "subscriptions.id DESC" ).limit( 15 ).select{ |p| !@joined.include?( p ) }
        end
        render layout: "bootstrap"
      end
      format.json do
        scope = Project.all
        if params[:featured] && params[:latitude]
          scope = scope.featured_near_point( params[:latitude], params[:longitude] )
        else
          scope = scope.featured if params[:featured]
          scope = scope.near_point(params[:latitude], params[:longitude]) if params[:latitude] && params[:longitude]
        end
        scope = scope.in_group(params[:group]) if params[:group]
        scope = scope.from_source_url(params[:source]) if params[:source]
        @projects = scope.paginate(:page => params[:page], :per_page => 100)
        opts = Project.default_json_options.merge(:include => [
          :project_list, 
          {:project_observation_fields => ProjectObservationField.default_json_options}
        ])
        opts[:methods] << :project_observations_count
        render :json => @projects.to_json(opts)
      end
    end
  end
  
  def browse
    @place = Place.find(params[:place_id]) rescue nil
    if !@place && @site && (@site_place = @site.place)
      @place = @site.place unless params[:everywhere].yesish?
    end
    @order = params[:order] if ORDERS.include?(params[:order])
    @order ||= 'title'
    @projects = Project.not_flagged_as_spam.
      page(params[:page]).order(ORDER_CLAUSES[@order])
    @projects = @projects.in_place(@place) if @place
    respond_to do |format|
      format.html
    end
  end

  def convert_to_collection
    project_user = current_user.project_users.where(project_id: @project.id).first
    if !current_user.has_role?(:admin) && ( project_user.blank? || !project_user.is_admin? )
      flash[:error] = t(:only_the_project_admin_can_do_that)
      redirect_to @project
      return
    end
    @project.convert_to_collection_project
    Project.refresh_es_index
    redirect_to @project
  end

  def convert_to_traditional
    project_user = current_user.project_users.where(project_id: @project.id).first
    if !current_user.has_role?(:admin) && ( project_user.blank? || !project_user.is_admin? )
      flash[:error] = t(:only_the_project_admin_can_do_that)
      redirect_to @project
      return
    end
    @project.convert_collection_project_to_traditional_project
    Project.refresh_es_index
    redirect_to @project
  end

  def show
    respond_to do |format|

      list_observed_and_total = @project.list_observed_and_total
      @list_denom = list_observed_and_total[:denominator]
      @list_numerator = list_observed_and_total[:numerator]

      format.html do
        @fb_admin_ids = ProviderAuthorization.joins(:user => :project_users).
          where("provider_authorizations.provider_name = 'facebook'").
          where("project_users.project_id = ? AND project_users.role = ?", @project, ProjectUser::MANAGER).
          map(&:provider_uid)
        @fb_admin_ids += CONFIG.facebook.admin_ids if CONFIG.facebook && CONFIG.facebook.admin_ids
        @fb_admin_ids = @fb_admin_ids.compact.map(&:to_s).uniq
        # check if the project can be previewed as a new-style project
        if params.has_key?(:collection_preview) && logged_in? && !@project.is_new_project?
          project_user = current_user.project_users.where(project_id: @project.id).first
          if current_user.has_role?(:admin) || ( project_user && project_user.is_admin? )
            if @project.can_be_converted_to_collection_project?
              preview = true
            else
              flash.now[:notice] = "This project cannot be converted"
            end
          end
        end
        # if previewing new-style project, make sure the projects index has the
        # properties that new-style projects would have, and sync the ES index
        if preview
          @project.convert_properties_for_collection_project
          @project.elastic_index!
          Project.refresh_es_index
        end
        # if previewing, or the project is a new-style, fetch the API
        # response and render the React projects show page
        if @project.is_new_project? || preview
          projects_response = INatAPIService.get( "/projects/#{@project.id}?rule_details=true=&ttl=-1" )
          if projects_response.blank?
            flash[:error] = I18n.t( :doh_something_went_wrong )
            return redirect_to projects_path
          end
          @projects_data = projects_response.results[0]
          @current_tab = params[:tab]
          @current_subtab = params[:subtab]
          return render layout: "bootstrap", action: "show2"
        end
        if logged_in?
          @provider_authorizations = current_user.provider_authorizations.all
        end
        @project_users = @project.project_users.includes(:user).
          paginate(:page => 1, :per_page => 5).order("id DESC")
        @members_count = @project_users.total_entries
        search_params = Observation.get_search_params( { projects: [@project.id] }, current_user: current_user )
        @observations = Observation.page_of_results( search_params )
        Observation.preload_for_component( @observations, logged_in: !!current_user )
        @project_journal_posts = @project.posts.published.order("published_at DESC").limit(4)
        @custom_project = @project.custom_project
        @project_assets = @project.project_assets.limit(100)
        @logo_image = @project_assets.detect{|pa| pa.asset_file_name =~ /logo\.(png|jpg|jpeg|gif)/}    
        @kml_assets = @project_assets.select{|pa| pa.asset_file_name =~ /\.km[lz]$/}
        if @place = @project.place
          if @project.prefers_place_boundary_visible
            @place_geometry = PlaceGeometry.without_geom.where(:place_id => @place).first
          end
        end
        @project_assessments = @project.assessments.incomplete.order("assessments.id DESC").limit(5)
        @observations_url_params = { projects: [@project.slug] }
        @observations_url = observations_url(@observations_url_params)
        @observation_search_url_params = { place_id: "any", verifiable: "any", project_id: @project.slug }
        if logged_in? && @project_user.blank?
          @project_user_invitation = @project.project_user_invitations.where(:invited_user_id => current_user).first
        end

        if params[:iframe]
          @headless = @footless = true
          top_observers_scope = @project.project_users.limit(10)
          @top_observers = if @project.project_type == "observation contest"
            top_observers_scope.order("observations_count desc, taxa_count desc").where("observations_count > 0")
          else
            top_observers_scope.order("taxa_count desc, observations_count desc").where("taxa_count > 0")
          end
          render :action => "show_iframe"
        elsif params[:test]
          render action: 'show_test', layout: 'bootstrap'
        end
      end
      
      format.json do
        opts = Project.default_json_options.merge(:include => [
          :project_list, 
          {:project_observation_fields => ProjectObservationField.default_json_options}
        ])
        opts[:methods] << :project_observations_count
        opts[:methods] << :list_observed_and_total
        opts[:methods] << :posts_count

        render :json => @project.as_json(opts)
      end
    end
  end

  def bulk_template
    csv = @project.generate_bulk_upload_template
    send_data(csv, { :filename => "#{@project.title.parameterize}.csv", :type => :csv })
  end

  def new_traditional
    @project = Project.new
  end

  def new
    render layout: "bootstrap"
  end

  def edit
    if @project.is_new_project?
      projects_response = INatAPIService.get( "/projects/#{@project.id}?rule_details=true=&ttl=-1" )
      if projects_response.blank?
        flash[:error] = I18n.t( :doh_something_went_wrong )
        return redirect_to projects_path
      end
      @project_json = projects_response.results[0]
      return render layout: "bootstrap", action: "new"
    end
    @project_assets = @project.project_assets.limit(100)
    @kml_assets = @project_assets.select{|pa| pa.asset_file_name =~ /\.km[lz]$/}
    if @place = @project.place
      if @project.prefers_place_boundary_visible
        @place_geometry = PlaceGeometry.without_geom.where(place_id: @place).first
      end
    end
    @project_curators = @project.project_users.
      where( "role IN (?)", ProjectUser::ROLES ).
      where( "user_id != ?", @project.user_id ).
      limit( 100 ).
      includes(:user).order( "users.login" )
  end

  def create
    @project = Project.new(params[:project].merge(:user_id => current_user.id))

    respond_to do |format|
      if @project.save
        Project.refresh_es_index
        format.html { redirect_to(@project, :notice => t(:project_was_successfully_created)) }
        format.json {
          render :json => @project.to_json
        }
      else
        format.html { render :action => "new_traditional" }
        format.json { render :status => :unprocessable_entity,
          :json => { :error => @project.errors.full_messages } }
      end
    end
  end

  # PUT /projects/1
  # PUT /projects/1.xml
  def update
    @project.icon = nil if params[:icon_delete]
    @project.cover = nil if params[:cover_delete]
    respond_to do |format|
      if @project.update_attributes(params[:project])
        Project.refresh_es_index
        format.html { redirect_to(@project, :notice => t(:project_was_successfully_updated)) }
        format.json { render json: @project }
      else
        format.html { render :action => "edit" }
        format.json { render json: @project.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /projects/1
  # DELETE /projects/1.xml
  def destroy
    project_user = current_user.project_users.where(project_id: @project.id).first
    if project_user.blank? || !project_user.is_admin?
      flash[:error] = t(:only_the_project_admin_can_delete_this_project)
      redirect_to @project
      return
    end
    
    if @project.is_new_project?
      # new projects can be destroyed immediately as they will have no
      # project observations
      @project.sane_destroy
    else
      @project.delay( priority: USER_INTEGRITY_PRIORITY,
        unique_hash: { "Project::sane_destroy": @project.id } ).sane_destroy
    end

    respond_to do |format|
      format.html do
        flash[:notice] = t(:project_x_was_delete, :project => @project.title)
        redirect_to(projects_url)
      end
      format.json do
        Project.refresh_es_index
        head :ok
      end
    end
  end
  
  def terms
    @project_observation_rules = @project.project_observation_rules.limit(100)
    @project_user_rules = @project.project_user_rules.limit(100)
    respond_to do |format|
      format.html
    end
  end
  
  def by_login
    respond_to do |format|
      format.html do
        @started = @selected_user.projects.order("id desc").limit(100)
        @project_users = @selected_user.project_users.joins(:project, :user).
          paginate(:page => params[:page]).order("lower(projects.title)")
        @projects = @project_users.map{|pu| pu.project}
      end
      format.json do
        @project_users = @selected_user.project_users.joins(:project).
          includes({:project => [:project_list, {:project_observation_fields => :observation_field}]}, :user).
          order("lower(projects.title)").
          limit(1000)
        project_options = Project.default_json_options.update(
          :include => [
            :project_list, 
            {
              :project_observation_fields => ProjectObservationField.default_json_options
            }
          ]
        )
        project_options[:methods] << :project_observation_rule_terms
        render :json => @project_users.to_json(:include => {
          :user => {:only => :login},
          :project => project_options
        })
      end
    end
  end
  
  def members
    @project_users = @project.project_users.joins(:user).
      paginate(:page => params[:page]).order("users.login ASC")
    respond_to do |format|
      format.html do
        @admin = @project.user
        @curators = @project.project_users.curators.limit(500).includes(:user).map{|pu| pu.user}
        @managers = @project.project_users.managers.limit(500).includes(:user).map{|pu| pu.user}
      end
      format.json { render json: @project_users.as_json(:include => {user: User.default_json_options}) }
    end
  end
  
  def observed_taxa_count
    @observed_taxa_count = @project.observed_taxa_count
    @list_count = @project.project_list.listed_taxa.count
    respond_to do |format|
      format.html do
        render :partial => "projects/observed_taxa_count_widget"
      end
      format.widget do
        render :js => render_to_string(:partial => "projects/observed_taxa_count_widget.js.erb")
      end
    end
  end
  
  def contributors
    if params[:sort] == "observation+contest"
      @contributors = @project.project_users.where("observations_count > 0").paginate(page: params[:page]).order("observations_count DESC, taxa_count DESC")
      @top_contributors = @project.project_users.where("taxa_count > 0").order("observations_count DESC, taxa_count DESC").limit(5)
    else
      @contributors = @project.project_users.where("taxa_count > 0").paginate(page: params[:page]).order("taxa_count DESC, observations_count DESC")
      @top_contributors = @project.project_users.where("taxa_count > 0").order("taxa_count DESC, observations_count DESC").limit(5)
    end
    respond_to do |format|
      format.html do
      end
      format.widget do
        render :js => render_to_string(:partial => "widget.js.erb")
      end
    end
  end
  
  def show_contributor
    @contributor = @project.project_users.find_by_id(params[:project_user_id].to_i)
    @contributor ||= @project.project_users.joins(:user).where(users: { login: params[:project_user_id] }).first
    if @contributor.blank?
      flash[:error] = t(:contributor_cannot_be_found)
      redirect_to project_contributors_path(@project)
      return
    end
    
    @project_observations = @project.project_observations.joins(:observation).
      where(observations: { user_id: @contributor.user }).
      paginate(page: params[:page], per_page: 28)

    @research_grade_count = @project.project_observations.
      joins(:observation).
      where(observations: { user_id: @contributor.user,
        quality_grade: Observation::RESEARCH_GRADE }).count

    @research_grade_species_count = @project.project_observations.
      joins(observation: :taxon).
      where(observations: { user_id: @contributor.user,
        quality_grade: Observation::RESEARCH_GRADE }).
      where("taxa.rank_level < ?", Taxon::GENUS_LEVEL).count
  end
  
  def list
    # TODO this causes a temporary table sort, which == badness
    @listed_taxa =  ProjectList.where(project_id: @project.id).first.listed_taxa.
      joins("LEFT OUTER JOIN taxon_photos ON taxon_photos.taxon_id = listed_taxa.taxon_id " +
        "LEFT OUTER JOIN photos ON photos.id = taxon_photos.photo_id").
      where("photos.id IS NOT NULL").
      select("MAX(listed_taxa.id) AS id, listed_taxa.taxon_id").
      group("listed_taxa.taxon_id").
      paginate(page: 1, per_page: 11).
      order("id DESC")
    @taxa = Taxon.where(id: @listed_taxa.map(&:taxon_id)).
      includes(:photos, :taxon_names)
    

    # Load tips HTML
    @taxa.map! do |taxon|
      taxon.html = render_to_string(:partial => 'taxa/taxon.html.erb', 
        :object => taxon, :locals => {
          :image_options => {:size => 'small'},
          :link_image => true,
          :link_name => true,
          :include_image_attribution => true
      })
      taxon
    end
  end
  
  def change_role
    @project_user = @project.project_users.find_by_id(params[:project_user_id])
    current_project_user = current_user.project_users.where(project_id: @project.id).first
    role = params[:role] if ProjectUser::ROLES.include?(params[:role])
    
    if @project_user.blank?
      flash[:error] = t(:project_user_cannot_be_found)
      redirect_to project_members_path(@project)
      return
    end
    
    unless current_project_user.is_manager?
      flash[:error] = t(:only_a_project_manager_can_add)
      redirect_to project_members_path(@project)
      return
    end
    
    @project_user.role = role
    
    if @project_user.save
      flash[:notice] = t(:grant_role, :grant => role.blank? ? t(:removed) : t(:added), :role => role)
      redirect_to project_members_path(@project)
    else
      flash[:error] = t(:project_user_was_invalid, :project_user => @project_user.errors.full_messages.to_sentence)
      redirect_to project_members_path(@project)
      return
    end
  end
  
  def remove_project_user
    @project_user = @project.project_users.find_by_id(params[:project_user_id])
    if @project_user.blank?
      flash[:error] = t(:project_user_cannot_be_found)
      redirect_to project_members_path(@project)
      return
    end
    if @project.user_id != current_user.id
      flash[:error] = t(:only_an_admin_can_remove_project_users)
      redirect_to project_members_path(@project)
      return
    end
    Project.delay(:priority => USER_INTEGRITY_PRIORITY).delete_project_observations_on_leave_project(@project.id, @project_user.user.id)
    if @project_user.destroy
      flash[:notice] = t(:removed_project_user)
      redirect_to project_members_path(@project)
    else
      flash[:error] = t(:project_user_was_invalid, :project_user => @project_user.errors.full_messages.to_sentence)
      redirect_to project_members_path(@project)
      return
    end
  end
  
  def join
    if @project.is_new_project?
      redirect_to @project
      return
    end
    @observation = Observation.find_by_id(params[:observation_id])
    @project_curators = @project.project_users.where(role: [ProjectUser::MANAGER, ProjectUser::CURATOR])
    if @project_user
      respond_to_join(:notice => t(:you_are_already_a_member_of_this_project))
      return
    end
    unless request.post?
      @project_user_invitation = @project.project_user_invitations.where(:invited_user_id => current_user).first
      respond_to do |format|
        format.html do
          if partial = params[:partial]
            render :layout => false, :partial => "projects/#{partial}"
          else
            # just render the default
          end
        end
        format.json { render :json => @project }
      end
      return
    end
    
    @project_user = @project.project_users.create((params[:project_user] || {}).merge(user: current_user))
    unless @observation
      if @project_user.valid?
        respond_to_join(:notice => t(:welcome_to_x_project, :project => @project.title))
      else
        respond_to_join(:error => t(:sorry_there_were_problems_with_your_request, :project_user => @project_user.errors.full_messages.to_sentence))
      end
      return
    end
    
    unless @project_user.valid?
      respond_to_join(:dest => @observation,
        :error => t(:sorry_there_were_problems_with_your_request, :project_user => @project_user.errors.full_messages.to_sentence))
      return
    end
    
    @project_observation = ProjectObservation.create(:project => @project, :observation => @observation)
    unless @project_observation.valid?
      respond_to_join(:dest => @observation,
        :error => t(:there_were_problems_adding_that_observation_to_this_project, :project_observation => @project_observation.errors.full_messages.to_sentence))
      return
    end
    
    if @project_invitation = ProjectInvitation.where(project_id: @project.id, observation_id: @observation.id).first
      @project_invitation.destroy
    end
    
    respond_to_join(:dest => @observation, :notice => t(:youve_joined_the_x_project, :project_invitation => @project_invitation.project.title))
  end

  def confirm_leave
    @project_requires_curator_coordinate_access = @project.project_observation_rules.detect do |por|
      por.operator == 'coordinates_shareable_by_project_curators?'
    end
    respond_to do |format|
      format.html
    end
  end
  
  def leave
    unless @project_user && (request.post? || request.delete?)
      respond_to do |format|
        format.html do
          flash[:error] = t(:you_arent_a_member_of_that_project)
          redirect_to @project
        end
        format.json do
          render :status => :ok, :json => {}
        end
      end
      return
    end
    
    if @project_user.user_id == @project.user_id
      msg = t(:you_cant_leave_a_project_you_created)
      respond_to do |format|
        format.html do
          flash[:error] = msg
          redirect_to @project
        end
        format.json do
          render :status => :unprocessable_entity, :json => {:error => msg}
        end
      end
      return
    end
    
    
    unless @project_user.role == nil
      Project.delay(:priority => USER_INTEGRITY_PRIORITY).update_curator_idents_on_remove_curator(@project.id, @project_user.user.id)
    end
    if params[:keep] == 'revoke'
      Project.delay(:priority => USER_INTEGRITY_PRIORITY).revoke_project_observations_on_leave_project(@project.id, @project_user.user.id)
    elsif !params[:keep].yesish?
      Project.delay(:priority => USER_INTEGRITY_PRIORITY).delete_project_observations_on_leave_project(@project.id, @project_user.user.id)
    end
    @project_user.destroy
    
    respond_to do |format|
      format.html do
        flash[:notice] = t(:you_have_left_x_project, :project => @project.title)
        redirect_to @project
      end
      
      format.json do
        render :status => :ok, :json => {}
      end
    end
  end

  def calendar
    @projects = Project.where(project_type: Project::BIOBLITZ_TYPE).order("start_time ASC, end_time ASC").
      where("end_time > ?", Time.now).joins(:place).where("places.id IS NOT NULL")
    unless params[:place_id].blank?
      @place = Place.find(params[:place_id]) rescue nil
    end
    @projects = @projects.in_place(@place) if @place
    if @eventsonly = params[:eventsonly].yesish?
      @projects = @projects.where("(end_time - start_time) < '2 weeks'::interval")
    end
    respond_to do |format|
      format.html do
        @projects = @projects.page(params[:page]).includes(:place)
        @finished = Project.where(project_type: Project::BIOBLITZ_TYPE).order("end_time DESC, start_time ASC").where("end_time < ?", Time.now).page(1)
        @finished = @finished.in_place(@place) if @place
        render layout: 'bootstrap'
      end
      format.ics do
        @projects = @projects.limit(500).includes(place: :user)
      end
    end
  end
  
  def stats
    @project_user_stats = Hash[
      @project.project_users.
        group("date_trunc('month', created_at)").
        count.map{|k,v| [k.to_s[/\d{4}-\d{2}/, 0], v]}
    ]
    @project_observation_stats = Observation.elastic_search(
      size: 0,
      filters: [
        { terms: { project_ids: [@project.id] } }
      ],
      aggregate: {
        year_months: {
          date_histogram: {
            field: "created_at",
            interval: "month",
            format: "yyyy-MM",
            keyed: true
          }
        }
      }
    ).response.aggregations.year_months.buckets
    @project_observation_stats = Hash[@project_observation_stats.map{|year_month, bucket| [year_month, bucket.doc_count]}]
    @unique_observer_stats = Observation.elastic_search(
      size: 0,
      filters: [
        { terms: { project_ids: [@project.id] } }
      ],
      aggregate: {
        year_months: {
          date_histogram: {
            field: "created_at",
            interval: "month",
            format: "yyyy-MM",
            keyed: true
          },
          aggs: {
            distinct_users: {
              cardinality: {
                field: "user.id"
              }
            }
          }
        }
      }
    ).response.aggregations.year_months.buckets
    @unique_observer_stats = Hash[@unique_observer_stats.map{|year_month, bucket| [year_month, bucket.distinct_users.value]}]
    @total_project_users = @project.project_users.count
    @total_project_observations = @project_observation_stats.values.sum
    @total_unique_observers = Observation.elastic_search(
      size: 0,
      filters: [
        { terms: { project_ids: [@project.id] } }
      ],
      aggregate: {
        distinct_users: {
          cardinality: {
            field: "user.id"
          }
        }
      }
    ).response.aggregations.distinct_users.value
    @headers = [t(:year_month), t(:new_members), t(:new_observations), t(:unique_observers)]
    @data = []
    (@project_user_stats.keys + @project_observation_stats.keys + @unique_observer_stats.keys).uniq.each do |key|
      @data << [key, @project_user_stats[key].to_i, @project_observation_stats[key].to_i, @unique_observer_stats[key].to_i]
    end
    @data.sort_by!(&:first).reverse!
    
    respond_to do |format|
      format.html
      format.json do
        opts = {}
        opts[:project_id] = @project.id
        opts[:project_title] = @project.title
        opts[:total_project_users] = @total_project_users
        opts[:total_project_observations] = @total_project_observations
        opts[:total_unique_observers] = @total_unique_observers
        opts[:data] = []
        @data.each do |data|
          per_period = Hash.new
          data.each_with_index { |d, i| per_period[@headers[i].gsub(/[ \/]/, '_')] = d }
          opts[:data] << per_period
        end
        render :json => opts
      end
      format.csv do 
        csv_text = CSV.generate(:headers => true) do |csv|
          csv << @headers
          @data.each {|row| csv << row}
        end
        render :text => csv_text
      end
    end
  end
  
  def add
    error_msg = nil
    unless @observation = Observation.find_by_id(params[:observation_id])
      error_msg = t(:that_observation_doesnt_exist)
    end

    if @project_observation = ProjectObservation.where(
        :project_id => @project.id, :observation_id => @observation.id).first
      error_msg = t(:the_observation_was_already_added_to_that_project)
    end

    @project_observation = ProjectObservation.create(project: @project, observation: @observation, user: current_user)
    
    unless @project_observation.valid?
      error_msg = t(:there_were_problems_adding_that_observation_to_this_project) + 
        @project_observation.errors.full_messages.to_sentence
    end

    if error_msg
      respond_to do |format|
        format.html do
          flash[:error] = error_msg
          if error_msg =~ /must belong to a member/
            redirect_to join_project_path(@project)
          else
            redirect_back_or_default(@project)
          end
        end
        format.json do
          json = {
            :error => error_msg,
            :errors => @project_observation.errors.full_messages,
            :project_observation => @project_observation
          }
          if @project_observation.errors.full_messages.to_sentence =~ /observation field/
            json[:observation_fields] = @project.project_observation_fields.as_json(:include => :observation_field)
          end
          render :status => :unprocessable_entity, :json => json
        end
      end
      return
    end
    
    respond_to do |format|
      format.html do
        flash[:notice] = t(:observation_added_to_the_project, :project => @project.title)
        redirect_back_or_default(@project)
      end
      format.json do
        Observation.refresh_es_index
        render :json => @project_observation.to_json(:include => {
          :observation => {:include => :observation_field_values}, 
          :project => {:include => :project_observation_fields}
        })
      end
    end
  end
  
  def remove
    @project_observation = @project.project_observations.find_by_observation_id(params[:observation_id])
    error_msg = if @project_observation.blank?
      t(:that_observation_hasnt_been_added_this_project)
    elsif !@project_observation.removable_by?(current_user)
      "you don't have permission to remove that observation"
    end

    unless error_msg.blank?
      respond_to do |format|
        format.html do
          flash[:error] = error_msg
          redirect_back_or_default(@project)
        end
        format.json { render :status => :unprocessable_entity, :json => {
          :error => error_msg
        }}
      end
      return
    end
    
    @project_observation.destroy
    respond_to do |format|
      format.html do
        flash[:notice] = t(:observation_removed_from_the_project, :project => @project.title)
        redirect_back_or_default(@project)
      end
      format.json do
        Observation.refresh_es_index
        render :json => @project_observation
      end
    end
  end
  
  def add_batch
    observation_ids = observation_ids_batch_from_params
    
    @observations = Observation.where(id: observation_ids, user_id: current_user.id)
    
    @errors = {}
    @project_observations = []
    @observations.each do |observation|
      project_observation = ProjectObservation.create(project: @project, observation: observation, user: current_user)
      if project_observation.valid?
        @project_observations << project_observation
      else
        @errors[observation.id] = project_observation.errors.full_messages
      end
      
      if @project_invitation = ProjectInvitation.where(project_id: @project.id, observation_id: observation.id).first
        @project_invitation.destroy
      end
      
    end
    
    @unique_errors = @errors.values.flatten.uniq.to_sentence
    
    if @observations.empty?
      flash[:error] = "You must specify at least one observation to add the project \"#{@project.title}\""
    elsif @project_observations.empty?
      flash[:error] = "None of those observations could be added to the project \"#{@project.title}\""
      flash[:error] += ": #{@unique_errors}" unless @unique_errors.blank?
    else
      flash[:notice] = "#{@project_observations.size} of #{@observations.size} added to the project \"#{@project.title}\""
      if @project_observations.size < @observations.size
        flash[:notice] += ". Some observations failed to add for the following reasons: #{@unique_errors}"
      end
    end
    
    # Cache the errors in case the next action wants to show the details
    Rails.cache.write("proj_obs_errors_#{current_user.id}", {:project_id => @project.id, :errors => @errors})
    
    redirect_back_or_default(observations_by_login_path(current_user.login))
  end
  
  def remove_batch
    observation_ids = observation_ids_batch_from_params
    @project_observations = @project.project_observations.where(observation_id: observation_ids).
      includes(:observation)
    
    @project_observations.each do |project_observation|
      next unless project_observation.removable_by?(current_user)
      project_observation.destroy
    end
    
    flash[:notice] = t(:observations_removed_from_the_project, :project => @project.title)
    redirect_back_or_default(@project)
    return
  end

  def search
    if @site && (@site_place = @site.place)
      @place = @site.place unless params[:everywhere].yesish?
    end
    if @q = params[:q]
      filters = [
        {
          multi_match: {
            query: @q,
            operator: "and",
            fields: [ :title, :description ],
            type: "phrase"
          }
        }
      ]
      filters << { term: { place_ids: @place.id } } if @place
      @projects = Project.elastic_paginate( filters: filters, page: params[:page] )
    end
    respond_to do |format|
      format.html
      format.json do
        opts = Project.default_json_options.merge(:include => [
          :project_list, 
          {:project_observation_fields => ProjectObservationField.default_json_options}
        ])
        render :json => @projects.to_json(opts)
      end
    end
  end

  def invite
    @project_user_invitations = @project.project_user_invitations.includes(:user, :invited_user).page(params[:page]).
      joins("LEFT OUTER JOIN project_users ON project_users.user_id = project_user_invitations.invited_user_id AND project_users.project_id = #{@project.id}").
      where("project_users.id IS NULL").order("project_user_invitations.id DESC")
    respond_to do |format|
      format.html
    end
  end

  def stats_slideshow
    if @project.title == Project::NPS_BIOBLITZ_PROJECT_NAME
      return redirect_to nps_bioblitz_stats_path
    end
    begin
      @slideshow_project = {
        id: @project.id,
        title: @project.title.sub("2016 National Parks BioBlitz - ", ""),
        slug: @project.slug,
        start_time: @project.start_time,
        end_time: @project.end_time,
        place_id: (@project.place || @project.rule_place).try(:id),
        observation_count: @project.observations.count,
        in_progress: @project.event_in_progress?,
        species_count: @project.node_api_species_count || 0
      }
    rescue
      sleep(2)
      return redirect_to stats_slideshow_project_path(@project)
    end

    render layout: "basic"
  end

  def change_admin
    current_project_user = current_user.project_users.where( project_id: @project.id ).first
    if current_project_user.blank? || !current_project_user.is_admin?
      flash[:error] = t(:only_the_project_admin_can_do_that)
      redirect_to @project
      return
    end
    new_admin = User.find_by_id( params[:user_id] )
    unless @project.curated_by?( new_admin )
      flash[:error] = t(:only_curators_can_become_the_new_admin)
      redirect_to @project
      return
    end
    @project.update_attributes( user: new_admin )
    redirect_back_or_default @project
  end

  private
  
  def load_project
    @project = Project.find(params[:id]) rescue nil
    render_404 unless @project
  end

  def ensure_current_project_url
    fmt = request.format && request.format != :html ? request.format.to_sym : nil
    if request.path != project_path(@project, :format => fmt)
      return redirect_to project_path(@project, :format => fmt), :status => :moved_permanently
    end
  end
  
  def load_project_user
    if logged_in? && @project
      @project_user = @project.project_users.find_by_user_id(current_user.id)
    end
  end
  
  def observation_ids_batch_from_params
    if params[:observations].is_a? Array
      params[:observations].map(&:first)
    elsif params[:o].is_a? String
      params[:o].split(',')
    else
      []
    end
  end
  
  def ensure_can_edit
    unless @project.editable_by?(current_user)
      flash[:error] = t(:you_dont_have_permission_to_edit_that_project)
      return redirect_to @project
    end
    true
  end
  
  def respond_to_join(options = {})
    error = options[:error]
    notice = options[:notice]
    dest = options[:dest] || @project || session[:return_to]
    respond_to do |format|
      if error
        format.html do
          flash[:error] = error
          redirect_to dest
        end
        
        format.json do
          render :status => :unprocessable_entity, :json => {:errors => @project_user.errors.full_messages}
        end
      else
        format.html do
          flash[:notice] = notice
          redirect_to dest
        end
        
        format.json do
          render :json => @project_user
        end
      end
    end
  end
  
  def filter_params
    params[:project].delete(:featured_at) unless current_user.is_admin?
    if current_user.is_admin?
      params[:project][:featured_at] = params[:project][:featured_at] == "1" ? Time.now : nil
    else
      params[:project].delete(:featured_at)
    end
    if params[:project][:project_type] != Project::BIOBLITZ_TYPE && !current_user.is_curator?
      params[:project].delete(:prefers_aggregation)
    end
    true
  end
end
