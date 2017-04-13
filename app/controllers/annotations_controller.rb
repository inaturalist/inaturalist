class AnnotationsController < ApplicationController
  before_action :doorkeeper_authorize!, if: ->{ authenticate_with_oauth? }
  before_filter :authenticate_user!, unless: ->{ authenticated_with_oauth? }
  before_filter :load_annotation, only: [:update, :destroy]

  def create
    p = annotation_params(params[:annotation])
    @annotation = Annotation.new(p)
    if !@annotation.save
      flash[:error] = @annotation.errors.full_messages.to_sentence
    end
    respond_to do |format|
      format.html do
        redirect_to @annotation.resource
      end
      format.json do
        if @annotation.errors.any?
          head :bad_request
        else
          Observation.refresh_es_index
          render :json => @annotation.as_json
        end
      end
    end
  end

  def destroy
    @annotation.destroy
    respond_to do |format|
      format.html do
        redirect_to @annotation.resource
      end
      format.json do
        Observation.refresh_es_index
        head :ok
      end
    end
  end

  private
  def load_annotation
    @annotation =
      Annotation.find_by_uuid(params[:id]) ||
      Annotation.find_by_id(params[:id])
    render_404 unless @annotation
  end

  def annotation_params(p)
    p[:user_id] ||= current_user.id
    p.permit(
      :resource_id,
      :resource_type,
      :controlled_attribute_id,
      :controlled_value_id,
      :user_id
    )
  end
end
