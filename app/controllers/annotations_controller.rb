# frozen_string_literal: true

class AnnotationsController < ApplicationController
  before_action :doorkeeper_authorize!, if: -> { authenticate_with_oauth? }
  before_action :authenticate_user!, unless: -> { authenticated_with_oauth? }
  before_action :load_record, only: [:show, :update, :destroy]

  def show
    respond_to do | format |
      format.html do
        return render_404 unless @annotation

        redirect_to @annotation.resource
      end
    end
  end

  def create
    p = annotation_params( params[:annotation] )
    @annotation = Annotation.new( p )
    unless @annotation.save
      flash[:error] = @annotation.errors.full_messages.to_sentence
    end
    respond_to do | format |
      format.html do
        redirect_to @annotation.resource
      end
      format.json do
        if @annotation.errors.any?
          head :bad_request
        else
          @annotation.reload
          render json: @annotation.as_json
        end
      end
    end
  end

  def destroy
    if @annotation&.deleteable_by?( current_user )
      @annotation.destroy
    end
    respond_to do | format |
      format.html do
        redirect_to @annotation.resource
      end
      format.json do
        head :ok
      end
    end
  end

  private

  def annotation_params( anno_params )
    anno_params[:user_id] ||= current_user.id
    anno_params.permit(
      :resource_id,
      :resource_type,
      :controlled_attribute_id,
      :controlled_value_id,
      :user_id
    )
  end
end
