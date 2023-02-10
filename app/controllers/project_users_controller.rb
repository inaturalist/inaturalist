class ProjectUsersController < ApplicationController
  before_action :doorkeeper_authorize!, if: ->{ authenticate_with_oauth? }
  before_action :authenticate_user!, unless: ->{ authenticated_with_oauth? }
  before_action :load_record, :require_owner
  def update
    respond_to do |format|
      format.json do
        if @project_user.update(project_user_params)
          render json: @project_user
        else
          render status: :unprocessable_entity, json: {errors: @project_user.errors}
        end
      end
    end
  end

  private
  def project_user_params(options = {})
    p = options.blank? ? (params[:project_user] || {}) : options
    p.permit(
      :preferred_curator_coordinate_access,
      :preferred_updates,
      :prefers_curator_coordinate_access_for,
      :prefers_updates
    )
  end
end
