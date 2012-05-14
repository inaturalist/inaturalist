class ProjectsController < ApplicationController
  WIDGET_CACHE_EXPIRATION = 15.minutes
  caches_action :observed_taxa_count, :contributors,
    :expires_in => WIDGET_CACHE_EXPIRATION,
    :cache_path => Proc.new {|c| c.params}, 
    :if => Proc.new {|c| c.request.format.widget?}
  
  before_filter :return_here, :only => [:index, :show, :contributors, :members, :show_contributor, :terms]
  before_filter :login_required, :except => [:index, :show, :search, :map, :contributors, :observed_taxa_count]
  before_filter :load_project, :except => [:create, :index, :search, :new, :by_login, :map, :browse]
  before_filter :ensure_current_project_url, :only => :show
  before_filter :load_project_user, :except => [:index, :search, :new, :by_login]
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
        project_observations = ProjectObservation.all(
          :select => "MAX(id) AS id, project_id",
          :order => "id desc", :limit => 9, :group => "project_id")
        @projects = Project.all(:conditions => ["id IN (?)", project_observations.map(&:project_id)])
        @created = Project.all(:order => "id desc", :limit => 9)
        @featured = Project.featured.all
        if logged_in?
          @started = current_user.projects.all(:order => "id desc", :limit => 9)
          @joined = current_user.project_users.all(:include => :project, :order => "id desc", :limit => 9).map(&:project)
        end
      end
      format.json do
        scope = Project.scoped({})
        scope = scope.featured if params[:featured]
        scope = scope.near_point(params[:latitude], params[:longitude]) if params[:latitude] && params[:longitude]
        scope = scope.from_source_url(params[:source]) if params[:source]
        @projects = scope.paginate(:page => params[:page], :per_page => 100)
        opts = Project.default_json_options.merge(:include => :project_list)
        opts[:methods] << :project_observations_count
        render :json => @projects.to_json(opts)
      end
    end
  end
  
  def browse
    @order = params[:order] if ORDERS.include?(params[:order])
    @order ||= 'title'
    @projects = Project.paginate(:page => params[:page], :order => ORDER_CLAUSES[@order])
  end
  
  def show
    respond_to do |format|
      format.any(:html, :mobile) do
        if logged_in?
          @provider_authorizations = current_user.provider_authorizations.all
        end
        @observed_taxa_count = @project.observed_taxa_count
        @top_observers = @project.project_users.all(:order => "taxa_count desc, observations_count desc", :limit => 10, :conditions => "taxa_count > 0")
        @project_users = @project.project_users.paginate(:page => 1, :per_page => 5, :include => :user, :order => "id DESC")
        @project_observations = @project.project_observations.paginate(:page => 1, 
          :include => {
            :observation => :iconic_taxon,
            :curator_identification => [:user, :taxon]
          }, :order => "id DESC")
        @observations = @project_observations.map(&:observation)
        @custom_project = @project.custom_project
        @project_assets = @project.project_assets.all(:limit => 100)
        @logo_image = @project_assets.detect{|pa| pa.asset_file_name =~ /logo\.(png|jpg|jpeg|gif)/}    
        @kml_assets = @project_assets.select{|pa| pa.asset_content_type == "application/vnd.google-earth.kml+xml"}
        if @place = @project.rule_place
          @place_geometry = PlaceGeometry.without_geom.first(:conditions => {:place_id => @place})
        end
        
        if params[:iframe]
          @headless = @footless = true
          render :action => "show_iframe"
        end
      end
      
      format.json do
        render :json => @project
      end
    end
  end

  def new
    @project = Project.new
  end

  def edit
  end

  def create
    @project = Project.new(params[:project].merge(:user_id => current_user.id))

    respond_to do |format|
      if @project.save
        format.html { redirect_to(@project, :notice => 'Project was successfully created.') }
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
        format.html { redirect_to(@project, :notice => 'Project was successfully updated.') }
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
      flash[:error] = "Only the project admin can delete this project."
      redirect_to @project
      return
    end
    
    @project.destroy
    
    respond_to do |format|
      format.html do
        flash[:notice] = "#{@project.title} was deleted"
        redirect_to(projects_url)
      end
    end
  end
  
  def terms
    @project_observation_rules = @project.project_observation_rules.all(:limit => 100)
    @project_user_rules = @project.project_user_rules.all(:limit => 100)
  end
  
  def by_login
    @started = @selected_user.projects.all(:order => "id desc", :limit => 100)
    @project_users = @selected_user.project_users.paginate(:page => params[:page],
      :include => [:project, :user],
      :order => "lower(projects.title)")
    @projects = @project_users.map{|pu| pu.project}
    respond_to do |format|
      format.html
      format.json do
        project_options = Project.default_json_options.update(:include => :project_list)
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
  end
  
  def observed_taxa_count
    @observed_taxa_count = @project.observed_taxa_count
    @list_count = @project.project_list.listed_taxa.count
    respond_to do |format|
      format.html do
      end
      format.widget do
        render :js => render_to_string(:partial => "observed_taxa_count_widget.js.erb")
      end
    end
  end
  
  def contributors
    @contributors = @project.project_users.paginate(:page => params[:page], :order => "taxa_count DESC, observations_count DESC", :conditions => "taxa_count > 0")
    @top_contributors = @project.project_users.all(:order => "taxa_count DESC, observations_count DESC", :conditions => "taxa_count > 0", :limit => 5)
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
      flash[:error] = "Contributor cannot be found"
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
    @taxa = Taxon.all(:conditions => ["id IN (?)", @listed_taxa.map(&:taxon_id)],
      :include => [:photos, :taxon_names])
    

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
      flash[:error] = "Project user cannot be found"
      redirect_to project_members_path(@project)
      return
    end
    
    unless current_project_user.is_manager?
      flash[:error] = "Only a project manager can add project curator status"
      redirect_to project_members_path(@project)
      return
    end
    
    @project_user.role = role
    
    if @project_user.save
      flash[:notice] = "#{role.blank? ? 'Removed' : 'Added'} #{role} role"
      redirect_to project_members_path(@project)
    else
      flash[:error] = "Project user was invalid: #{@project_user.errors.full_messages.to_sentence}"
      redirect_to project_members_path(@project)
      return
    end
  end
  
  def remove_project_user
    @project_user = @project.project_users.find_by_id(params[:project_user_id])
    if @project_user.blank?
      flash[:error] = "Project user cannot be found"
      redirect_to project_members_path(@project)
      return
    end
    if @project.user_id != current_user.id
      flash[:error] = "Only an admin can remove project users"
      redirect_to project_members_path(@project)
      return
    end
    Project.send_later(:delete_project_observations_on_leave_project, @project.id, @project_user.user.id)
    if @project_user.destroy
      flash[:notice] = "Removed project user"
      redirect_to project_members_path(@project)
    else
      flash[:error] = "Project user was invalid: #{@project_user.errors.full_messages.to_sentence}"
      redirect_to project_members_path(@project)
      return
    end
  end
  
  def join
    @observation = Observation.find_by_id(params[:observation_id])
    @project_curators = @project.project_users.all(:conditions => ["role IN (?)", [ProjectUser::MANAGER, ProjectUser::CURATOR]])
    if @project_user
      respond_to_join(:notice => "You're already a member of this project!")
      return
    end
    return unless request.post?
    
    @project_user = @project.project_users.create(:user => current_user)
    unless @observation
      if @project_user.valid?
        respond_to_join(:notice => "Welcome to #{@project.title}")
      else
        respond_to_join(:error => "Sorry, there were problems with your request: #{@project_user.errors.full_messages.to_sentence}")
      end
      return
    end
    
    unless @project_user.valid?
      respond_to_join(:dest => @observation,
        :error => "Sorry, there were problems with your request: #{@project_user.errors.full_messages.to_sentence}")
      return
    end
    
    @project_observation = ProjectObservation.create(:project => @project, :observation => @observation)
    unless @project_observation.valid?
      respond_to_join(:dest => @observation, 
        :error => "There were problems adding your observation to this project: #{@project_observation.errors.full_messages.to_sentence}")
      return
    end
    
    if @project_invitation = ProjectInvitation.first(:conditions => {:project_id => @project.id, :observation_id => @observation.id})
      @project_invitation.destroy
    end
    
    respond_to_join(:dest => @observation, :notice => "You've joined the \"#{@project_invitation.project.title}\" project and your observation was added")
  end
  
  def leave
    unless @project_user && (request.post? || request.delete?)
      respond_to do |format|
        format.html do
          flash[:error] = "You aren't a member of that project."
          redirect_to @project
        end
        format.json do
          render :status => :ok, :json => {}
        end
      end
      return
    end
    
    if @project_user.user_id == @project.user_id
      msg = "You can't leave a project you created."
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
      Project.send_later(:update_curator_idents_on_remove_curator, @project.id, @project_user.user.id)
    end
    Project.send_later(:delete_project_observations_on_leave_project, @project.id, @project_user.user.id)
    @project_user.destroy
    
    respond_to do |format|
      format.html do
        flash[:notice] = "You have left #{@project.title}"
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
    (@project_user_stats.keys + @project_observation_stats.keys + @unique_observer_stats.keys).uniq.sort.reverse.each do |key|
      @data << [key, @project_user_stats[key].to_i, @project_observation_stats[key].to_i, @unique_observer_stats[key].to_i]
    end
    
    respond_to do |format|
      format.html
      format.csv do 
        csv_text = FasterCSV.generate(:headers => true) do |csv|
          csv << @headers
          @data.each {|row| csv << row}
        end
        render :text => csv_text
      end
    end
  end
  
  def add
    unless @observation = Observation.find_by_id(params[:observation_id])
      flash[:error] = "That observation doesn't exist."
      redirect_back_or_default(@project)
      return
    end
    if @project_observation = ProjectObservation.first(:conditions => { :project_id => @project.id, :observation_id => @observation.id })
      flash[:error] = "The observation was already added to that project."
      redirect_back_or_default(@project)
      return
    end
    @project_observation = ProjectObservation.create(:project => @project, :observation => @observation)
    unless @project_observation.valid?
      flash[:error] = "There were problems adding your observation to this project: " + 
        @project_observation.errors.full_messages.to_sentence
      redirect_back_or_default(@project)
      return
    end
    
    if @project_invitation = ProjectInvitation.first(:conditions => {:project_id => @project.id, :observation_id => @observation.id})
      @project_invitation.destroy
    end
    
    flash[:notice] = "Observation added to the project \"#{@project.title}\""
    redirect_back_or_default(@project)
  end
  
  def remove
    unless @project_observation = @project.project_observations.find_by_observation_id(params[:observation_id])
      flash[:error] = "That observation hasn't been added this project."
      redirect_back_or_default(@project)
      return
    end
    
    unless @project_observation.observation.user_id == current_user.id || (@project_user && @project_user.is_curator?)
      flash[:error] = "You can't remove other people's observations."
      redirect_back_or_default(@project)
      return
    end
    
    @project_observation.destroy
    flash[:notice] = "Observation removed from the project \"#{@project.title}\""
    redirect_back_or_default(@project)
    return
  end
  
  def add_batch
    observation_ids = observation_ids_batch_from_params
    
    @observations = Observation.all(
      :conditions => [
        "id IN (?) AND user_id = ?", 
        observation_ids,
        current_user.id
      ]
    )
    
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
    
    @unique_errors = @errors.values.uniq.to_sentence
    
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
    @project_observations = @project.project_observations.all(
      :include => :observation,
      :conditions => ["observation_id IN (?)", observation_ids]
    )
    
    @project_observations.each do |project_observation|
      next unless project_observation.observation.user_id == current_user.id
      project_observation.destroy
    end
    
    flash[:notice] = "Observations removed from the project \"#{@project.title}\""
    redirect_back_or_default(@project)
    return
  end
  
  def search
    if @q = params[:q]
      @projects = Project.paginate(:page => params[:page], :conditions => ["lower(title) LIKE ?", "%#{@q.downcase}%"])
    end
    respond_to do |format|
      format.html
      format.json do
        render :json => @projects.to_json(:methods => [:icon_url], :include => :project_list)
      end
    end
  end
  
  private
  
  def load_project
    @project = Project.find(params[:id]) rescue nil
    render_404 unless @project
  end
  
  def ensure_current_project_url
    return redirect_to @project, :status => :moved_permanently unless @project.friendly_id_status.best?
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
      flash[:error] = "You don't have permission to edit that project."
      return redirect_to @project
    end
    true
  end
  
  def respond_to_join(options = {})
    error = options[:error]
    notice = options[:notice]
    dest = options[:dest] || @project
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
    true
  end
end
