class ObservationFieldValuesController < ApplicationController
  before_filter :authenticate_user!
  before_filter :load_observation_field_value, :only => [:update, :destroy]
  
  def create
    @observation_field_value = ObservationFieldValue.new(params[:observation_field_value])
    
    respond_to do |format|
      if @observation_field_value.save
        format.json { render :json => @observation_field_value }
      else
        format.json do
          render :status => :unprocessable_entity, :json => {:errors => @observation_field_value.errors.full_messages }
        end
      end
    end
  end

  def update
    respond_to do |format|
      if @observation_field_value.update_attributes(params[:observation_field_value])
        format.json { render :json => @observation_field_value }
      else
        format.json do
          render :status => :unprocessable_entity, :json => {:errors => @observation_field_value.errors.full_messages }
        end
      end
    end
  end
  
  def destroy
    if @observation_field_value.blank?
      status = :gone
      json = "Observation field value #{params[:id]} does not exist."
    elsif @observation_field_value.observation.user_id != current_user.id
      status = :forbidden
      json = "You do not have permission to do that."
    else
      @observation_field_value.destroy
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

  private
  def load_observation_field_value
    @observation_field_value = ObservationFieldValue.find_by_id(params[:id])
    render_404 unless @observation_field_value
  end
end