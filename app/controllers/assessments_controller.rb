class AssessmentsController < ApplicationController

  def new
    project = Project.find_by_slug(params[:project_id])

    if ! (project.curated_by? current_user)
      flash[:error] = "Only the project admins and curators can create new assessments on this project."
      redirect_to project
      return
    end

    @assessment = Assessment.new
    @assessment.project = project
    @assessment.sections.build
  end

  def create
    project = Project.find(params[:assessment][:project_id])

    if ! (project.curated_by? current_user)
      flash[:error] = "Only the project admins and curators can create new assessments on this project."
      redirect_to project
      return
    end

    @assessment = Assessment.new(params[:assessment].merge(:user_id => current_user.id))
    @assessment.project = project

    @assessment.sections.build if @assessment.sections == []
    @assessment.sections.map {|section| section.user = current_user }

    if @assessment.completed_at.blank? && params['completed'].present?
      @assessment.completed_at = Time.now
    end
    if @assessment.completed_at.present? && params['completed'].blank?
      @assessment.completed_at = nil
    end

    @parent_display_name = @assessment.taxon_name
    if params[:preview]
      @headless = @footless = true
      render :partial => 'show' 
      return
    end

    respond_to do |format|
      if @assessment.valid? && ! params[:preview]
        @assessment.save
        format.html { redirect_to(@assessment, :notice => 'Assessment was successfully created.') }
      else
        format.html { render :action => "new" }
      end
    end
  end

  def update
    @assessment = Assessment.find(params[:id])
    @parent_display_name = @assessment.taxon_name

    if ! @assessment.project.curated_by? current_user
      redirect_to @assessment, :notice => "You must be a curator, admin, or owner to edit this assessment."
      return
    end

    if @assessment.completed_at.blank? && params['completed'].present?
      @assessment.completed_at = Time.now
    end
    if @assessment.completed_at.present? && params['completed'].blank?
      @assessment.completed_at = nil
    end

    if params[:preview]
      @assessment.assign_attributes(params[:assessment])
      @headless = @footless = true
      render :partial => 'show' 
      return
    end

    respond_to do |format|
    if @assessment.update_attributes(params[:assessment])
        format.html { redirect_to(@assessment, :notice => 'Assessment was successfully updated.') }
      else
        format.html { render :action => "edit" }
      end
    end
  end

  def show
    if params[:iframe]
      @headless = @footless = true
    end
    @assessment = Assessment.find(params[:id])
    @parent_display_name = @assessment.taxon_name
  end

  def edit
     @assessment = Assessment.find(params[:id])
  end

  def index
    @project = Project.find_by_slug(params[:project_id])
    @parent_display_name = @project.title
    respond_to do |format|
      format.html do
        @uncompleted_assessments = Assessment.where(:project_id => @project.id).incomplete
        @completed_assessments = Assessment.where(:project_id => @project.id).complete.
          paginate(:page => params[:page])
      end
      format.json do
        @assessments = @project.assessments.page(params[:page]).per_page(100)
        @assessments = if params[:complete] = 'true'
          @assessments.complete
        elsif params[:complete] = 'false'
          @assessments.complete
        end
        render :json => @assessments
      end
    end
  end


  def destroy
    @assessment = Assessment.find(params[:id])
    @project = @assessment.project
    if ! @assessment.project.curated_by? current_user
      redirect_to @assessment, :notice => "You must be a curator, admin, or owner to delete this assessment."
      return
    end

    # unless @project.deletable_by?(current_user)
    #  msg = "You don't have permission to do that"
    @assessment.destroy
    redirect_to(@assessment.project, :notice => 'Assessment was deleted.')
  end

  def show_section
    @section = Section.find(params[:id])
    @section.delete!
    @project = @assessment.project
    redirect_to assessment_section_path(@project), :anchor => 'fragment_identifier'
  end

end # class


