class ProjectsController < ApplicationController
  WIDGET_CACHE_EXPIRATION = 15.minutes
  # caches_action :observed_taxa_count, :contributors,
  #   :expires_in => WIDGET_CACHE_EXPIRATION,
  #   :cache_path => Proc.new {|c| c.params}, 
  #   :if => Proc.new {|c| c.request.format == :widget}

  before_action :doorkeeper_authorize!, :only => [ :by_login, :join, :leave ], :if => lambda { authenticate_with_oauth? }
  
  before_filter :return_here, :only => [:index, :show, :contributors, :members, :show_contributor, :terms, :invite]
  before_filter :authenticate_user!, 
    :unless => lambda { authenticated_with_oauth? },
    :except => [:index, :show, :search, :map, :contributors, :observed_taxa_count, :browse]
  load_except = [ :create, :index, :search, :new, :by_login, :map, :browse ]
  before_filter :load_project, :except => load_except
  blocks_spam :except => load_except, :instance => :project
  before_filter :ensure_current_project_url, :only => :show
  before_filter :load_project_user, :except => [:index, :search, :new, :by_login]
  before_filter :load_user_by_login, :only => [:by_login]
  before_filter :ensure_can_edit, :only => [:edit, :update]
  before_filter :filter_params, :only => [:update, :create]

  MOBILIZED = [:join]
  before_filter :unmobilized, :except => MOBILIZED
  before_filter :mobilized, :only => MOBILIZED
  
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
        project_observations = ProjectObservation.
          select("MAX(project_observations.id) AS id, project_id").
          order("id DESC").
          limit(9).
          group('project_id')
        if @place
          project_observations = project_observations.joins(:project => :place).where(@place.self_and_descendant_conditions)
        end
        @projects = Project.where("projects.id IN (?)",
          project_observations.map(&:project_id)).not_flagged_as_spam
        @created = Project.not_flagged_as_spam.order("projects.id desc").limit(9)
        @created = @created.joins(:place).where(@place.self_and_descendant_conditions) if @place
        @featured = Project.featured
        @featured = @featured.joins(:place).where(@place.self_and_descendant_conditions) if @place
        if logged_in?
          @started = current_user.projects.not_flagged_as_spam.
            all(:order => "projects.id desc", :limit => 9)
          @joined = current_user.project_users.joins(:project).
            merge(Project.not_flagged_as_spam).includes(:project).
            order("projects.id desc").limit(9).map(&:project)
        end
      end
      format.json do
        scope = Project.all
        scope = scope.featured if params[:featured]
        scope = scope.in_group(params[:group]) if params[:group]
        scope = scope.near_point(params[:latitude], params[:longitude]) if params[:latitude] && params[:longitude]
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
  
  def show
    respond_to do |format|

      list_observed_and_total = @project.list_observed_and_total
      @list_denom = list_observed_and_total[:denominator]
      @list_numerator = list_observed_and_total[:numerator]

      format.html do
        if logged_in?
          @provider_authorizations = current_user.provider_authorizations.all
        end
        @observations_count = current_user.observations.count if current_user
        @observed_taxa_count = @project.observed_taxa_count
        top_observers_scope = @project.project_users.limit(10)
        @top_observers = if @project.project_type == "observation contest"
          top_observers_scope.order("observations_count desc, taxa_count desc").where("observations_count > 0")
        else
          top_observers_scope.order("taxa_count desc, observations_count desc").where("taxa_count > 0")
        end
        @project_users = @project.project_users.paginate(:page => 1, :per_page => 5, :include => :user, :order => "id DESC")
        @members_count = @project_users.total_entries
        @project_observations = @project.project_observations.page(1).
          includes([
            { :observation => [ :iconic_taxon,
                                :projects,
                                :quality_metrics,
                                :stored_preferences,
                                :taxon,
                                { :observation_photos => :photo },
                                { :user => :stored_preferences } ] },
            { :curator_identification => [:user, :taxon] }
          ]).
          order("project_observations.id DESC")
        @project_observations_count = @project_observations.count
        @observations = @project_observations.map(&:observation) unless @project.project_type == 'bioblitz'
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
        @fb_admin_ids = ProviderAuthorization.joins(:user => :project_users).
          where("provider_authorizations.provider_name = 'facebook'").
          where("project_users.project_id = ? AND project_users.role = ?", @project, ProjectUser::MANAGER).
          map(&:provider_uid)
        @fb_admin_ids += CONFIG.facebook.admin_ids if CONFIG.facebook && CONFIG.facebook.admin_ids
        @fb_admin_ids = @fb_admin_ids.compact.map(&:to_s).uniq
        @observations_url = if @project.project_type == 'bioblitz'
          @observations_url_params = @project.observations_url_params
          observations_url(@observations_url_params)
        else
          project_observations_url(@project, :per_page => 24)
        end
        if logged_in? && @project_user.blank?
          @project_user_invitation = @project.project_user_invitations.where(:invited_user_id => current_user).first
        end

        if params[:iframe]
          @headless = @footless = true
          render :action => "show_iframe"
        end
      end
      
      format.json do
        opts = Project.default_json_options.merge(:include => [
          :project_list, 
          {:project_observation_fields => ProjectObservationField.default_json_options}
        ])
        opts[:methods] << :project_observations_count
        opts[:methods] << :list_observed_and_total

        render :json => @project.as_json(opts)
      end
    end
  end

  def bulk_template
    csv = @project.generate_bulk_upload_template
    send_data(csv, { :filename => "#{@project.title.parameterize}.csv", :type => :csv })
  end

  def new
    @project = Project.new
  end

  def edit
    @project_assets = @project.project_assets.limit(100)
    @kml_assets = @project_assets.select{|pa| pa.asset_file_name =~ /\.km[lz]$/}
    if @place = @project.place
      if @project.prefers_place_boundary_visible
        @place_geometry = PlaceGeometry.without_geom.first(:conditions => {:place_id => @place})
      end
    end
  end

  def create
    @project = Project.new(params[:project].merge(:user_id => current_user.id))

    respond_to do |format|
      if @project.save
        format.html { redirect_to(@project, :notice => t(:project_was_successfully_created)) }
      else
        format.html { render :action => "new" }
      end
    end
  end

  # PUT /projects/1
  # PUT /projects/1.xml
  def update
    @project.icon = nil if params[:icon_delete]
    respond_to do |format|
      if @project.update_attributes(params[:project])
        format.html { redirect_to(@project, :notice => t(:project_was_successfully_updated)) }
      else
        format.html { render :action => "edit" }
      end
    end
  end

  # DELETE /projects/1
  # DELETE /projects/1.xml
  def destroy
    project_user = current_user.project_users.first(:conditions => {:project_id => @project.id})
    if project_user.blank? || !project_user.is_admin?
      flash[:error] = t(:only_the_project_admin_can_delete_this_project)
      redirect_to @project
      return
    end
    
    @project.destroy
    
    respond_to do |format|
      format.html do
        flash[:notice] = t(:project_x_was_delete, :project => @project.title)
        redirect_to(projects_url)
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
        @project_users = @selected_user.project_users.paginate(:page => params[:page],
          :include => [:project, :user],
          :order => "lower(projects.title)")
        @projects = @project_users.map{|pu| pu.project}
      end
      format.json do
        @project_users = @selected_user.project_users.limit(1000).
          includes({:project => [:project_list, {:project_observation_fields => :observation_field}]}, :user).
          order("lower(projects.title)")
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
    @project_users = @project.project_users.paginate(:page => params[:page], :include => :user, :order => "users.login ASC")
    @admin = @project.user
    @curators = @project.project_users.curators.limit(500).includes(:user).map{|pu| pu.user}
    @managers = @project.project_users.managers.limit(500).includes(:user).map{|pu| pu.user}
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
      @contributors = @project.project_users.paginate(:page => params[:page], :order => "observations_count DESC, taxa_count DESC", :conditions => "observations_count > 0")
      @top_contributors = @project.project_users.where("taxa_count > 0").order("observations_count DESC, taxa_count DESC").limit(5)
    else
      @contributors = @project.project_users.paginate(:page => params[:page], :order => "taxa_count DESC, observations_count DESC", :conditions => "taxa_count > 0")
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
    @contributor ||= @project.project_users.first(:include => :user, :conditions => ["users.login = ?", params[:project_user_id]])
    if @contributor.blank?
      flash[:error] = t(:contributor_cannot_be_found)
      redirect_to project_contributors_path(@project)
      return
    end
    
    @project_observations = @project.project_observations.paginate(:page => params[:page], 
      :per_page => 28,
      :include => :observation, :conditions => ["observations.user_id = ?", @contributor.user])
    
    @research_grade_count = @project.project_observations.count(
      :joins => :observation,
      :conditions => [
        "observations.user_id = ? AND observations.quality_grade = ?", 
        @contributor.user,
        Observation::RESEARCH_GRADE
    ])
    
    @research_grade_species_count = @project.project_observations.count(
      :joins => {:observation => :taxon},
      :conditions => [
        "observations.user_id = ? AND observations.quality_grade = ? AND taxa.rank_level < ?", 
        @contributor.user,
        Observation::RESEARCH_GRADE,
        Taxon::GENUS_LEVEL
    ])
  end
  
  def list
    # TODO this causes a temporary table sort, which == badness
    @listed_taxa =  ProjectList.first(:conditions => { :project_id => @project.id }).listed_taxa.paginate(
      :page => 1,
      :per_page => 11,
      :select => "MAX(listed_taxa.id) AS id, listed_taxa.taxon_id",
      :joins => 
        "LEFT OUTER JOIN taxon_photos ON taxon_photos.taxon_id = listed_taxa.taxon_id " +
        "LEFT OUTER JOIN photos ON photos.id = taxon_photos.photo_id",
      :group => "listed_taxa.taxon_id",
      :order => "id DESC",
      :conditions => "photos.id IS NOT NULL"
    )
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
    current_project_user = current_user.project_users.first(:conditions => {:project_id => @project.id})
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
        format.mobile
        format.json { render :json => @project }
      end
      return
    end
    
    @project_user = @project.project_users.create(:user => current_user)
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
        :error => t(:there_were_problems_adding_your_observation_to_this_project, :project_observation => @project_observation.errors.full_messages.to_sentence))
      return
    end
    
    if @project_invitation = ProjectInvitation.first(:conditions => {:project_id => @project.id, :observation_id => @observation.id})
      @project_invitation.destroy
    end
    
    respond_to_join(:dest => @observation, :notice => t(:youve_joined_the_x_project, :project_invitation => @project_invitation.project.title))
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
    Project.delay(:priority => USER_INTEGRITY_PRIORITY).delete_project_observations_on_leave_project(@project.id, @project_user.user.id)
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
  
  def stats
    @project_user_stats = @project.project_users.count(:group => "EXTRACT(YEAR FROM created_at) || '-' || EXTRACT(MONTH FROM created_at)")
    @project_observation_stats = @project.project_observations.count(:group => "EXTRACT(YEAR FROM created_at) || '-' || EXTRACT(MONTH FROM created_at)")
    @unique_observer_stats = @project.project_observations.count(
      :select => "observations.user_id", 
      :include => :observation, 
      :group => "EXTRACT(YEAR FROM project_observations.created_at) || '-' || EXTRACT(MONTH FROM project_observations.created_at)")
    
    @total_project_users = @project.project_users.count
    @total_project_observations = @project.project_observations.count
    @total_unique_observers = @project.project_observations.count(:select => "observations.user_id", :include => :observation)
    
    @headers = ['year/month', 'new users', 'new observations', 'unique observers']
    @data = []
    (@project_user_stats.keys + @project_observation_stats.keys + @unique_observer_stats.keys).uniq.each do |key|
      display_key = key.gsub(/\-(\d)$/, "-0\\1")
      @data << [display_key, @project_user_stats[key].to_i, @project_observation_stats[key].to_i, @unique_observer_stats[key].to_i]
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
  
  def invitations
    scope = @project.observations_matching_rules
    if @project.place && !@project.project_observation_rules.detect{|por| por.operator == "observed_in_place?"}
      scope = scope.in_place(@project.place)
    end
    existing_scope = Observation.in_projects([@project])
    invited_scope = Observation.joins(:project_invitations).where("project_invitations.project_id = ?", @project.id)

    if params[:by] == "you"
      scope = scope.by(current_user)
      existing_scope = existing_scope.by(current_user)
      invited_scope = invited_scope.by(current_user)
    end

    if params[:on_list] == "yes"
      scope = scope.where("observations.taxon_id = listed_taxa.taxon_id").
        joins("JOIN listed_taxa ON listed_taxa.list_id = #{@project.project_list.id}")
      existing_scope = existing_scope.where("observations.taxon_id = listed_taxa.taxon_id").
        joins("JOIN listed_taxa ON listed_taxa.list_id = #{@project.project_list.id}")
      invited_scope = invited_scope.where("observations.taxon_id = listed_taxa.taxon_id").
        joins("JOIN listed_taxa ON listed_taxa.list_id = #{@project.project_list.id}")
    end
    
    scope_sql = scope.to_sql
    existing_scope_sql = existing_scope.to_sql
    invited_scope_sql = invited_scope.to_sql

    sql = "(#{scope_sql}) EXCEPT ((#{existing_scope_sql}) UNION (#{invited_scope_sql}))"
    @observations = Observation.paginate_by_sql(sql, :page => params[:page])
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

    @project_observation = ProjectObservation.create(:project => @project, :observation => @observation)
    
    unless @project_observation.valid?
      error_msg = t(:there_were_problems_adding_your_observation_to_this_project) + 
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
    elsif @project_observation.observation.user_id != current_user.id && (@project_user.blank? || !@project_user.is_curator?)
      t(:you_cant_remove_other_peoples_observations)
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
      project_observation = ProjectObservation.create(:project => @project, :observation => observation)
      if project_observation.valid?
        @project_observations << project_observation
      else
        @errors[observation.id] = project_observation.errors.full_messages
      end
      
      if @project_invitation = ProjectInvitation.first(:conditions => {:project_id => @project.id, :observation_id => observation.id})
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
      next unless project_observation.observation.user_id == current_user.id
      project_observation.destroy
    end
    
    flash[:notice] = t(:observations_removed_from_the_project, :project => @project.title)
    redirect_back_or_default(@project)
    return
  end

  def preview_matching
    @observations = scope_for_add_matching.page(1).per_page(10)
    if @project_user
      render :layout => false
    else
      render :unprocessable_entity
    end
  end

  def add_matching
    unless @project.users.where("users.id = ?", current_user).exists?
      msg = t(:you_must_be_a_member_of_this_project_to_do_that)
      respond_to do |format|
        format.html do
          flash[:error] = msg
          redirect_back_or_default(@project)
        end
        format.json { render :json => {:error => msg} }
      end
      return
    end

    added = 0
    failed = 0
    scope_for_add_matching.find_each do |observation|
      next if observation.project_observations.detect{|po| po.project_id == @project.id}
      pi = ProjectObservation.new(:observation => observation, :project => @project)
      if pi.save
        added += 1
      else
        failed += 1
      end
    end

    msg = if added == 0 && failed > 0
      "Failed to add all #{failed} matching observation(s) to #{@project.title}. Try adding observations individually to see error messages"
    elsif failed > 0
      "Added #{added} matching observation(s) to #{@project.title}, failed to add #{failed}. Try adding the rest individually to see error messages."
    else
      "Added #{added} matching observation(s) to #{@project.title}"
    end

    respond_to do |format|
      format.html do
        flash[:notice] = msg
        redirect_back_or_default(@project)
      end
      format.json do
        render :json => {:msg => msg}
      end
    end
  end
  
  def search
    if @site && (@site_place = @site.place)
      @place = @site.place unless params[:everywhere].yesish?
    end
    if @q = params[:q]
      opts = {:page => params[:page]}
      opts[:with] = {:place_ids => [@place.id]} if @place
      @projects = Project.search(@q, opts)
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
  
  private

  def scope_for_add_matching
    @taxon = Taxon.find_by_id(params[:taxon_id]) unless params[:taxon_id].blank?
    scope = @project.observations_matching_rules.
      by(current_user).
      includes(:taxon, :project_observations).
      where("project_observations.id IS NULL OR project_observations.project_id != ?", @project).
      scoped
    scope = scope.of(@taxon) if @taxon
    scope
  end
  
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
    dest = options[:dest] || session[:return_to] || @project
    respond_to do |format|
      if error
        format.any(:html, :mobile) do
          flash[:error] = error
          redirect_to dest
        end
        
        format.json do
          render :status => :unprocessable_entity, :json => {:errors => @project_user.errors.full_messages}
        end
      else
        format.any(:html, :mobile) do
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
    true
  end
end
