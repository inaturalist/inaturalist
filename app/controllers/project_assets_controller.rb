class ProjectAssetsController < ApplicationController
  before_filter :authenticate_user!
  before_filter :load_project_asset, :only => [:edit, :update, :destroy]
  before_filter :load_project
  before_filter do |c|
    c.require_admin_or_trusted_project_manager_for @project
  end
  
  # GET /project_assets/new
  # GET /project_assets/new.xml
  def new
    @project_asset = ProjectAsset.new(:project => @project)

    respond_to do |format|
      format.html
    end
  end

  # GET /project_assets/1/edit
  def edit
  end

  # POST /project_assets
  # POST /project_assets.xml
  def create
    @project_asset = ProjectAsset.new(params[:project_asset])

    respond_to do |format|
      if @project_asset.save
        format.html { redirect_to(@project, :notice => 'ProjectAsset was successfully created.') }
        format.xml  { render :xml => @project_asset, :status => :created, :location => @project_asset }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @project_asset.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /project_assets/1
  # PUT /project_assets/1.xml
  def update
    respond_to do |format|
      if @project_asset.update_attributes(params[:project_asset])
        format.html { redirect_to(@project, :notice => 'ProjectAsset was successfully updated.') }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @project_asset.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /project_assets/1
  # DELETE /project_assets/1.xml
  def destroy
    @project_asset.destroy
    respond_to do |format|
      format.html do
        flash[:notice] = "Asset deleted"
        redirect_to(@project)
      end
      format.xml  { head :ok }
    end
  end
  
  private
  def load_project_asset
    render_404 unless @project_asset = ProjectAsset.find_by_id(params[:id])
  end
  
  def load_project
    @project = @project_asset.project if @project_asset
    @project ||= Project.find_by_id(params[:project_id])
    @project ||= Project.find_by_id(params[:project_asset].try(:[], :project_id))
    unless @project
      flash[:error] = "No project selected"
      redirect_to projects_path
      return false
    end
    true
  end
end
