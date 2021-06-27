class ProjectObservationsController < ApplicationController
  before_action :doorkeeper_authorize!, :only => [ :show, :create, :update, :destroy ], :if => lambda { authenticate_with_oauth? }
  before_filter :authenticate_user!, :unless => lambda { authenticated_with_oauth? }
  before_filter :load_record, only: [:update, :destroy]
  
  def create
    begin
      @project_observation = ProjectObservation.new( project_observation_params_for_create )
    rescue ActionController::ParameterMissing => e
      respond_to do |format|
        format.json do
          render status: :unprocessable_entity, json: { errors: [e.message] }
        end
      end
      return
    end
    set_curator_coordinate_access
    existing = ProjectObservation.
      where(
        project_id: @project_observation.project_id,
        observation_id: @project_observation.observation_id
      ).first
    if existing
      @project_observation = existing
    else
      auto_join_project
      @project_observation.user = current_user
    end

    respond_to do |format|
      if @project_observation.save
        format.json { render json: @project_observation }
      else
        format.json do
          json = {
            errors: @project_observation.errors.full_messages,
            object: @project_observation
          }
          render status: :unprocessable_entity, json: json
        end
      end
    end
  end

  def update
    respond_to do |format|
      format.json do
        begin
          @project_observation.assign_attributes( project_observation_params_for_update )
        rescue ActionController::ParameterMissing => e
          render status: :unprocessable_entity, json: { errors: [e.message] }
          return
        end
        set_curator_coordinate_access
        if @project_observation.save
          @project_observation.observation.elastic_index!
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

  def project_observation_params_for_create
    params.require(:project_observation).permit(
      :observation_id,
      :project_id,
      :preferred_curator_coordinate_access,
      :prefers_curator_coordinate_access
    )
  end

  def project_observation_params_for_update
    params.require(:project_observation).permit(
      :preferred_curator_coordinate_access,
      :prefers_curator_coordinate_access
    )
  end

  def set_curator_coordinate_access
    if @project_observation.observation && current_user != @project_observation.observation.user
      @project_observation.prefers_curator_coordinate_access = @project_observation.prefers_curator_coordinate_access_was
    end
  end
  
end
