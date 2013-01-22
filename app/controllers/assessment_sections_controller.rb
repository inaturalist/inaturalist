class AssessmentSectionsController < ApplicationController

  def show
    # comments controller tries to display the commentable, but since we dont display this directly, redirect to the assessment
     @section = AssessmentSection.find(params[:id])
     redirect_to project_assessment_path(@section.assessment.project, @section.assessment, :anchor => @section.title.parameterize)
  end

end # class
