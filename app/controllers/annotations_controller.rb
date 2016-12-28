class AnnotationsController < ApplicationController
  before_action :doorkeeper_authorize!, if: ->{ authenticate_with_oauth? }
  before_filter :authenticate_user!, unless: ->{ authenticated_with_oauth? }
  before_filter :load_annotation, only: [:update, :destroy]

  def create
    p = annotation_params(params[:annotation])
    @annotation = Annotation.new(p)
    if @annotation.save
      redirect_to @annotation.resource
    else
      flash[:error] = @annotation.errors.full_messages.to_sentence
      redirect_to @annotation.resource
    end
  end

  def destroy
    @annotation.destroy
    redirect_to @annotation.resource
  end

  private
  def load_annotation
    @annotation = Annotation.find_by_id(params[:id])
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
