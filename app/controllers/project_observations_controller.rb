class ProjectObservationsController < ApplicationController
  before_action :doorkeeper_authorize!, :only => [ :show, :create, :update, :destroy ], :if => lambda { authenticate_with_oauth? }
  before_filter :authenticate_user!, :unless => lambda { authenticated_with_oauth? }
  before_filter :load_record, only: [:update, :destroy]
  
  def create
    @project_observation = ProjectObservation.new(params[:project_observation])
    auto_join_project
    @project_observation.user = current_user

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

  def update
    respond_to do |format|
      format.json do
        if @project_observation.update_attributes(project_observation_params)
          render json: @project_observation
        else
          render status: :unprocessable_entity, json: {errors: @project_observation.errors}
        end
      end
    end
  end
  
  def destroy
    if [@project_observation.user_id, @project_observation.observation.user_id].include?(current_user.id) || @project_observation.project.curated_by?(current_user)
      @project_observation.destroy  
      respond_to do |format|
        format.html do
          redirect_back_or_default(@project_observation.project)
        end
        format.json do
          head :no_content
        end
      end
    else
      respond_to do |format|
        format.html do
          flash[:notice] = I18n.t(:only_project_curators_can_do_that)
          redirect_back_or_default @project_observation.project
        end
        format.json do
          render json: {error: I18n.t(:only_project_curators_can_do_that)}, status: :unprocessable_entity
        end
      end
    end
  end

  private

  def auto_join_project
    @project = Project.find_by_id(params[:project_id])
    @project ||= Project.find(params[:project_id]) rescue nil
    return unless @project
    @project_user = current_user.project_users.find_or_create_by(project_id: @project.id)
    return unless @project_user
    if @project.tracking_code_allowed?(params[:tracking_code])
      @project_observation.tracking_code = params[:tracking_code]
    end
  end

  def project_observation_params
    params.require(:project_observation).permit(:preferred_curator_coordinate_access, :prefers_curator_coordinate_access)
  end
  
end
