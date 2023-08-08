class ProjectsController < ApplicationController
  WIDGET_CACHE_EXPIRATION = 15.minutes

  before_action :allow_external_iframes, only: [ :show ]

  caches_action :observed_taxa_count, :contributors,
    expires_in: WIDGET_CACHE_EXPIRATION,
    cache_path: Proc.new {|c| c.params},
    if: Proc.new {|c| c.request.format == :widget}

  ## AUTHENTICATION
  before_action :doorkeeper_authorize!,
    only: [:by_login, :join, :leave, :members, :feature, :unfeature],
    if: -> { authenticate_with_oauth? }
  before_action :authenticate_user!,
    unless: -> { authenticated_with_oauth? },
    except: [:index, :show, :search, :map, :contributors, :observed_taxa_count,
      :browse, :calendar, :stats_slideshow]
  protect_from_forgery with: :exception, if: lambda {
    !request.format.widget? && request.headers["Authorization"].blank?
  }
  ## /AUTHENTICATION

  before_action :admin_or_this_site_admin_required, only: [ :feature, :unfeature ]
  before_action :return_here,
    only: [ :index, :show, :contributors, :members, :show_contributor, :terms, :invite ]
  load_except = [ :create, :index, :search, :new_traditional, :by_login, :map, :browse, :calendar, :new ]
  before_action :load_project, except: load_except
  blocks_spam except: load_except, instance: :project
  check_spam only: [:create, :update], instance: :project
  before_action :ensure_current_project_url, only: :show
  before_action :load_project_user,
    except: [ :index, :search, :new_traditional, :by_login, :new, :feature, :unfeature ]
  before_action :load_user_by_login, only: [ :by_login ]
  before_action :ensure_can_edit, only: [ :edit, :update ]
  before_action :filter_params, only: [ :update, :create ]
  before_action :site_required, only: [ :feature, :unfeature ]

  prepend_around_action :enable_replica, only: [:show]

  requires_privilege :organizer, only: [:new_traditional]
  
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

        base_params = { site_id: @site.id, ttl: 600 }
        if current_user && ( current_user.is_admin? || current_user.site_admins.any? )
          base_params[:ttl] = -1
        end
        carousel_r = INatAPIService.projects( base_params.merge(
          noteworthy: true,
          order_by: "featured",
          per_page: 3
        ) )

        carousel_ids = ( carousel_r ? carousel_r.results : [] ).map{ |p| p["id"] }
        @carousel = Project.where(id: carousel_ids).to_a

        featured_r = INatAPIService.projects( base_params.merge(
          featured: true,
          not_id: @carousel.map(&:id),
          order_by: "featured",
          per_page: 11
        ) )
        featured_ids = ( featured_r ? featured_r.results : [] ).map{ |p| p["id"] }
        @featured = Project.where(id: featured_ids).to_a
        while @carousel.length < 3 && @featured.length > 0 do
          @carousel.push( @featured.shift )
        end
        @featured = @featured[0...8]

        recent_r = INatAPIService.projects( base_params.merge(
          not_id: @carousel.map(&:id) + @featured.map(&:id),
          per_page: 11,
          order_by: "recent_posts",
          place_id: @place.try(:id)
        ) )
        recent_ids = ( recent_r ? recent_r.results : [] ).map{ |p| p["id"] }
        @recent = Project.where(id: recent_ids).to_a
        while @carousel.length < 3 && @recent.length > 0 do
          @carousel.push( @recent.shift )
        end
        @recent = @recent[0...8]

        created_r = INatAPIService.projects( base_params.merge(
          not_id: @carousel.map(&:id) + @featured.map(&:id) + @recent.map(&:id),
          per_page: 8,
          order_by: "created",
          place_id: @place.try(:id),
          has_posts: true
        ) )
        created_ids = ( created_r ? created_r.results : [] ).map{ |p| p["id"] }
        @created = Project.where(id: created_ids).to_a

        Project.preload_associations( @carousel + @featured + @recent + @created, :stored_preferences )

        if logged_in?
          @started = current_user.projects.not_flagged_as_spam.
            order("projects.id desc").limit(5).includes(:stored_preferences)
          @joined = current_user.project_users.joins(:project).
            merge(Project.not_flagged_as_spam).includes( project: :stored_preferences ).
            where( "projects.user_id != ?", current_user ).
            order("projects.id desc").limit(5).map(&:project)
        end
        render layout: "bootstrap"
      end
      format.json do
        scope = Project.all
        # ensuring lat/lng are floats to prevent SQL injection in an order clause below
        if params[:latitude]
          params[:latitude] = Float(params[:latitude]) rescue nil
        end
        if params[:longitude]
          params[:longitude] = Float(params[:longitude]) rescue nil
        end
        if params[:featured] && params[:latitude] && params[:longitude]
          scope = scope.joins(:site_featured_projects)
          scope = scope.
            where(["projects.latitude IS NULL OR ST_Distance(ST_Point(projects.longitude, projects.latitude), ST_Point(?, ?)) < 5",
              params[:latitude], params[:longitude]]).
            order( Arel.sql(
              "CASE WHEN projects.latitude IS NULL THEN 6 ELSE ST_Distance(ST_Point(projects.longitude, projects.latitude), ST_Point(#{params[:latitude]}, #{params[:latitude]})) END"
            ) )
        else
          if params[:featured]
            scope = scope.joins(:site_featured_projects)
          end
          if params[:latitude] && params[:longitude]
            scope = scope.near_point(params[:latitude], params[:longitude])
          end
        end
        scope = scope.in_group(params[:group]) if params[:group]
        scope = scope.from_source_url(params[:source]) if params[:source]
        scope = scope.includes( { project_observation_rules: :operand }, :project_list, :place,
          { project_observation_fields: :observation_field }, :stored_preferences
        )
        @projects = scope.paginate(:page => params[:page], :per_page => 100).to_a.uniq
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

    filters = []
    if @place
      filters << { terms: { associated_place_ids: [@place.id] } }
    end
    sort = { title_exact: :asc }
    if @order == "created"
      sort = { created_at: :desc }
    end
    @projects = Project.elastic_paginate(
      filters: filters,
      inverse_filters: [
        { term: { spam: true } }
      ],
      sort: sort,
      page: params[:page]
    )

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
          @project.wait_for_index_refresh = true
          @project.elastic_index!
        end
        # if previewing, or the project is a new-style, fetch the API
        # response and render the React projects show page
        if @project.is_new_project? || preview
          projects_response = INatAPIService.project( @project.id, {
            rule_details: true,
            ttl: -1,
            authenticate: current_user
          } )
          if projects_response.blank?
            flash[:error] = I18n.t( :doh_something_went_wrong )
            return redirect_to projects_path
          end
          @projects_data = projects_response.results[0]
          @current_tab = params[:tab]
          @current_subtab = params[:subtab]
          @flash_js = true
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
        @site_feature = @project.site_featured_projects.where(site_id: @site.id).first

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
    @project_types = [Project::ASSESSMENT_TYPE]
  end

  def new
    if params[:copy_project_id]
      @copy_project = Project.find( params[:copy_project_id] ) rescue nil
      if @copy_project
        if @copy_project.is_new_project?
          projects_response = INatAPIService.project( params[:copy_project_id], { rule_details: true, ttl: -1 } )
          unless projects_response.blank?
            @copy_project_json = projects_response.results[0]
          end
        else
          flash.now[:notice] = I18n.t( "views.projects.new.traditional_projects_cannot_be_copied" )
        end
      end
    end
    render layout: "bootstrap"
  end

  def edit
    if @project.is_new_project?
      projects_response = INatAPIService.project( @project.id, {
        rule_details: true,
        ttl: -1,
        authenticate: current_user
      } )
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
    @project_types = @project.bioblitz? ? Project::PROJECT_TYPES : [Project::ASSESSMENT_TYPE]
  end

  def create
    @project = Project.new(params[:project].merge(:user_id => current_user.id))
    @project.wait_for_index_refresh = true
    respond_to do |format|
      if @project.save
        format.html { redirect_to(@project, :notice => t(:project_was_successfully_created)) }
        format.json {
          render :json => @project.to_json
        }
      else
        @project_types = [Project::ASSESSMENT_TYPE]
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
    if params[:project] && params[:project][:user_id]
      msg = if current_user.id != @project.user_id && @project.user_id != params[:project][:user_id].to_i
        I18n.t( "errors.messages.only_project_owner_can_change_project_owner" )
      elsif @project.user_id != params[:project][:user_id].to_i
        new_admin = User.find_by_id( params[:project][:user_id] )
        if new_admin.blank?
          I18n.t( :x_does_not_exist, x: I18n.t( :user ) )
        elsif !@project.project_users.where( user_id: new_admin, role: ProjectUser::MANAGER ).exists?
          I18n.t( "errors.messages.new_project_owner_must_be_a_manager" )
        end
      end
      if msg
        respond_to do |format|
          format.html do
            flash[:error] = msg
            redirect_back_or_default( @project )
          end
          format.json do
            render json: { error: msg }, status: :unprocessable_entity
          end
        end
        return
      end
    end
    respond_to do |format|
      # Project uses accepts_nested_attributes which saves associates after the main record,
      # potentially trigging a lot of indexing for things like ProjectUsers. So skip indexing the
      # project until the entire save/update process is done
      @project.skip_indexing = true
      saved_successfully = @project.update(params[:project])
      @project.wait_for_index_refresh = true
      @project.elastic_index!
      if saved_successfully
        format.html { redirect_to(@project, :notice => t(:project_was_successfully_updated)) }
        format.json { render json: @project }
      else
        @project_types = Project::PROJECT_TYPES
        @project_types = if [@project.project_type, @project.project_type_was].include?( Project::BIOBLITZ_TYPE )
          Project::PROJECT_TYPES
        else
          [Project::ASSESSMENT_TYPE]
        end
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
        @started = @selected_user.projects.
          paginate( page: params[:started_page], per_page: 7 ).order( Arel.sql( "lower( projects.title )" ) )
        @project_users = @selected_user.project_users.joins( :project, :user ).
          paginate( page: params[:main_page], per_page: 20 ).order( Arel.sql( "lower( projects.title )" ) )
        @projects = @project_users.map{ |pu| pu.project }
        render layout: "bootstrap"
      end
      format.json do
        @project_users = @selected_user.project_users.joins(:project).
          includes({
            project: [
              :project_list,
              { project_observation_rules: :operand },
              { project_observation_fields: :observation_field }
            ]
          }, :user).
          order( Arel.sql( "lower(projects.title)" ) ).
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
      paginate(:page => params[:page])
    @order_by = params[:order_by] || "login"
    @order = %w(asc desc).include?( params[:order] ) ? params[:order] : "asc"
    if params[:order_by] == "created_at"
      @project_users = @project_users.order( "project_users.id #{@order}" )
    else
      @project_users = @project_users.order( "users.login #{@order}" )
    end
    respond_to do |format|
      format.html do
        @admin = @project.user
        @curators = @project.project_users.curators.limit(500).includes(:user).map{|pu| pu.user}
        @managers = @project.project_users.managers.limit(500).includes(:user).map{|pu| pu.user}
        render layout: "bootstrap"
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
      format.html
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

    if @project.is_new_project?
      @observations = Observation.page_of_results({
        projects: [ @project ],
        user: @contributor.user,
        page: params[:page],
        per_page: 20
      })
    else
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

    @project.wait_for_index_refresh = true
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
    
    respond_to_join(:dest => @observation, :notice => t(:youve_joined_the_x_project, :project_invitation => @project.title))
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
    @project_user.project.wait_for_index_refresh = true
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
        render :plain => csv_text
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

    @project_observation = ProjectObservation.create(
      project: @project,
      observation: @observation,
      user: current_user
    )
    
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
      project_observation = ProjectObservation.create( project: @project, observation: observation,
        user: current_user, skip_touch_observation: true )
      if project_observation.valid?
        @project_observations << project_observation
      else
        @errors[observation.id] = project_observation.errors.full_messages
      end
    end
    Observation.elastic_index!( ids: @observations.map( &:id ) )
    
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
    if @q = params[:q]
      response = INatAPIService.get(
        "/search",
        q: @q,
        page: params[:page],
        sources: "projects",
        ttl: logged_in? ? "-1" : nil
      )
      projects = Project.where( id: response.results.map{|r| r["record"]["id"]} ).index_by(&:id)
      @projects = WillPaginate::Collection.create( response["page"] || 1, response["per_page"] || 0, response["total_results"] || 0 ) do |pager|
        pager.replace( response.results.map{|r| projects[r["record"]["id"]]} )
      end
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
    @project.update( user: new_admin )
    redirect_back_or_default @project
  end

  def feature
    feature = SiteFeaturedProject.where(site: @site, project: @project).
      first_or_create(user: @current_user)
    feature.update( user: @current_user )
    if feature.noteworthy && ( params[:noteworthy].nil? || params[:noteworthy].noish? )
      feature.update( noteworthy: false )
    elsif !feature.noteworthy && params[:noteworthy].yesish?
      feature.update( noteworthy: true )
    end
    render status: :ok, json: { }
  end

  def unfeature
    SiteFeaturedProject.where(
      site: @site, project: @project
    ).destroy_all
    render status: :ok, json: { }
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
    if params[:project][:project_type] != Project::BIOBLITZ_TYPE && !current_user.is_curator?
      params[:project].delete(:prefers_aggregation)
    end
    true
  end

  def site_required
    unless @site
      render status: :unprocessable_entity, json: { errors: "Site required" }
      return
    end
  end

end
