class ProjectObservationsController < ApplicationController
  doorkeeper_for :show, :create, :update, :destroy, :if => lambda { authenticate_with_oauth? }
  before_filter :authenticate_user!, :unless => lambda { authenticated_with_oauth? }
  
  def create
    @project_observation = ProjectObservation.new(params[:project_observation])
    
    respond_to do |format|
      if @project_observation.save
        format.json { render :json => @project_observation }
      else
        format.json do
          json = {
            :errors => @project_observation.errors.full_messages,
            :object => @project_observation
          }
          if json[:errors].to_s =~ /already added/
            if existing = @project_observation.project.project_observations.find_by_observation_id(@project_observation.observation_id)
              json[:existing] = existing
            end
          end
          render :status => :unprocessable_entity, :json => json
        end
      end
    end
  end
  
  def destroy
    @project_observation = ProjectObservation.find_by_id(params[:id])
    if @project_observation.blank?
      status = :gone
      json = "Project observation #{params[:id]} does not exist."
    elsif @project_observation.observation.user_id != current_user.id
      status = :forbidden
      json = "You do not have permission to do that."
    else
      @project_observation.destroy
      status = :ok
      json = nil
    end
    
    respond_to do |format|
      format.any do
        render :status => :status, :text => json
      end
      format.json do 
        render :status => status, :json => json
      end
    end
  end
  
end
