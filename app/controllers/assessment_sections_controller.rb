class AssessmentSectionsController < ApplicationController

#   def new
#     @section = AssessmentSection.new
#     @section.assessment = Assessment.find_by_id(params[:assessment_id])
#   end

#   def create
#     @section = AssessmentSection.new(params[:assessment_section])
#     @section.user = current_user
#     if @section.save
#         flash[:notice] = "Assessment Section Created!"
#         redirect_to project_assessment_path(@section.assessment.project, @section.assessment)
#     else
#       render :action => :new
#     end
#   end

  def show
    # comments controller tries to display the commentable, but since we dont display this directly, redirect to the assessment
     @section = AssessmentSection.find(params[:id])
     redirect_to project_assessment_path(@section.assessment.project, @section.assessment, :anchor => @section.title.parameterize)
  end

#   def edit
#      @section = AssessmentSection.find(params[:id])
#   end

#   def update
#   end

#   def destroy
#   end

end # class
