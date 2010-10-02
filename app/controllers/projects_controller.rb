class ProjectsController < ApplicationController
  before_filter :admin_required
  before_filter :login_required, :except => [:index, :show]
  before_filter :load_project, :only => [:show, :edit, :update, :destroy,
    :join, :leave, :add, :remove, :add_batch, :remove_batch]
  before_filter :load_project_user, :only => [:show, :edit, :update, :destroy,
    :join, :leave, :add, :remove]
  
  # GET /projects
  # GET /projects.xml
  def index
    @projects = Project.paginate(:page => params[:page])
  end
  
  def show
    @project_users = @project.project_users.paginate(:page => 1, :include => :user)
    @project_observations = @project.project_observations.paginate(:page => 1, :include => :observation)
    @observations = @project_observations.map(&:observation)
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
    @project = Project.find(params[:id])
    @project.destroy

    respond_to do |format|
      format.html do
        flash[:notice] = "#{@project.title} was deleted"
        redirect_to(projects_url)
      end
    end
  end
  
  
  def join
    return unless @project_user.blank? && request.post?
    @project_user = @project.project_users.create(:user => current_user)
    if @project_user.valid?
      flash[:notice] = "Welcome to #{@project.title}"
      redirect_to @project and return
    else
      flash[:error] = "Sorry, there were problems with your request: " + 
        @project_user.errors.full_messages.to_sentence
    end
  end
  
  def leave
    unless @project_user && request.post?
      flash[:error] = "You aren't a member of that project."
      redirect_to @project and return
    end
    @project_user.destroy
    flash[:notice] = "You have left #{@project.title}"
    redirect_to @project
  end
  
  def add
    unless @observation = Observation.find_by_id(params[:observation_id])
      flash[:error] = "That observation doesn't exist."
      redirect_to :back and return
    end
    
    @project_observation = ProjectObservation.create(:project => @project, :observation => @observation)
    unless @project_observation.valid?
      flash[:error] = "There were problems adding your observation to this project: " + 
        @project_observation.errors.full_messages.to_sentence
      redirect_to :back and return
    end
    
    flash[:notice] = "Observation added to the project \"#{@project.title}\""
    redirect_to :back
  end
  
  def remove
    unless @project_observation = @project.project_observations.find_by_observation_id(params[:observation_id])
      flash[:error] = "That observation hasn't been added this project."
      redirect_to :back and return
    end
    
    unless @project_observation.observation.user_id == current_user.id
      flash[:error] = "You can't remove other people's observations."
      redirect_to :back and return
    end
    
    @project_observation.destroy
    flash[:notice] = "Observation removed from the project \"#{@project.title}\""
    redirect_to :back
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
        @errors[observation.id] = project_observation.errors
      end
    end
    
    @unique_errors = @errors.values.map {|errors| errors.full_messages}.uniq.to_sentence
    
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
    
    redirect_to :back
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
    redirect_to :back
  end
  
  private
  
  def load_project
    render_404 unless @project = Project.find_by_id(params[:id])
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
end
