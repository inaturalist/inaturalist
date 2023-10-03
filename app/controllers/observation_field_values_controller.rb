class ObservationFieldValuesController < ApplicationController
  before_action :doorkeeper_authorize!, :only => [ :show, :create, :update, :destroy ], :if => lambda { authenticate_with_oauth? }
  before_action :authenticate_user!, :unless => lambda { authenticated_with_oauth? }
  before_action :load_observation_field_value, :only => [:update, :destroy]

  def create
    ofv_params = observation_field_value_params
    ofv_params.delete(:id) # why does rails even allow this...
    @observation_field_value = ObservationFieldValue.new(ofv_params)
    @observation_field_value.user = current_user
    if !@observation_field_value.valid?
      if existing = ObservationFieldValue.where(
          "observation_field_id = ? AND observation_id = ?", 
          @observation_field_value.observation_field_id, 
          @observation_field_value.observation_id).first
        @observation_field_value = existing
        @observation_field_value.attributes = ofv_params
      end
    end
    respond_to do |format|
      if @observation_field_value.save
        format.json { render :json => @observation_field_value }
      else
        format.json do
          render :status => :unprocessable_entity, :json => { :errors => @observation_field_value.errors.full_messages }
        end
      end
    end
  end

  def update
    respond_to do |format|
      update_params = observation_field_value_params
      if !update_params[:id].is_a? Integer
        update_params[:uuid] = update_params[:id]
        update_params.delete(:id)
      end
      if @observation_field_value.update(update_params)
        format.json { render :json => @observation_field_value }
      else
        format.json do
          render :status => :unprocessable_entity, :json => { :errors => @observation_field_value.errors.full_messages }
        end
      end
    end
  end
  
  def destroy
    errors = []
    if @observation_field_value.blank?
      status = :gone
      errors << "Observation field value #{params[:id]} does not exist."
    elsif @observation_field_value.observation.user_id != current_user.id &&
          @observation_field_value.user_id != current_user.id
      status = :forbidden
      errors << t(:you_dont_have_permission_to_do_that)
    else
      proj_requiring_field = @observation_field_value.observation.projects.detect do |proj|
        proj.project_observation_fields.detect do |pof|
          pof.required? && pof.observation_field_id === @observation_field_value.observation_field_id
        end
      end
      if proj_requiring_field
        status = :unprocessable_entity
        errors << t(:observation_belongs_to_project_requiring_field)
      else
        @observation_field_value.destroy
        status = :ok
      end
    end
    respond_to do |format|
      format.any do
        render status: status, plain: errors ? errors.join( ", " ) : nil
      end
      format.json do 
        render status: status, json: errors ? { errors: errors } : nil
      end
    end
  end

  private
  def load_observation_field_value
    @observation_field_value =
      ObservationFieldValue.find_by_uuid(params[:id]) ||
      ObservationFieldValue.find_by_id(params[:id])
    render_404 unless @observation_field_value
  end

  def observation_field_value_params(options = {})
    p = options.blank? ? params : options
    p = p[:observation_field_value] if p[:observation_field_value]
    p.delete(:id) if p[:id].to_i == 0
    p[:updater_id] = current_user.id if logged_in?
    p.permit(
      :id,
      :observation_id,
      :observation_field_id,
      :value,
      :updater_id
    )
  end
end
