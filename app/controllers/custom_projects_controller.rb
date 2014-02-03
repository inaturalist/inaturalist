class CustomProjectsController < ApplicationController
  before_filter :authenticate_user!
  before_filter :load_custom_project, :only => [:edit, :show, :update, :destroy]
  before_filter :load_project
  before_filter do |c|
    c.require_admin_or_trusted_project_manager_for @project
  end
  
  # GET /custom_projects/new
  # GET /custom_projects/new.xml
  def new
    @custom_project = CustomProject.new(:project => @project)

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @custom_project }
    end
  end

  # GET /custom_projects/1/edit
  def edit
  end

  # POST /custom_projects
  # POST /custom_projects.xml
  def create
    @custom_project = CustomProject.new(params[:custom_project])
    @custom_project.project ||= @project

    respond_to do |format|
      if @custom_project.save
        format.html { redirect_to(edit_project_path(@project), :notice => t(:custom_project_was_successfully_created)) }
        format.xml  { render :xml => @custom_project, :status => :created, :location => @custom_project }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @custom_project.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /custom_projects/1
  # PUT /custom_projects/1.xml
  def update
    #@message = current_user.messages.build(params[:message])

    respond_to do |format|
      if !params[:preview]
        if @custom_project.update_attributes(params[:custom_project])
          format.html { redirect_to(edit_project_path(@project), :notice => t(:custom_project_was_successfully_updated)) }
          format.xml  { head :ok }
        else
          format.html { render :action => "edit" }
          format.xml  { render :xml => @custom_project.errors, :status => :unprocessable_entity }
        end
      else
        if params[:preview]
          @custom_project.head = view_context.formatted_user_text(@custom_project.head)
        end
          render :json => @custom_project.to_json(:methods => [:html])
      end
    end
  end

  # DELETE /custom_projects/1
  # DELETE /custom_projects/1.xml
  def destroy
    @custom_project.destroy

    respond_to do |format|
      format.html { redirect_to(@project) }
      format.xml  { head :ok }
    end
  end
  
  private
  def load_custom_project
    render_404 unless @custom_project = CustomProject.find_by_id(params[:id])
  end
  
  def load_project
    @project = @custom_project.project if @custom_project
    @project ||= Project.find_by_id(params[:project_id])
    @project ||= Project.find_by_id(params[:custom_project].try(:[], :project_id))
    unless @project
      flash[:error] = t(:no_project_selected)
      redirect_to projects_path
      return false
    end
    true
  end
end
