class ControlledTermsResourcesController < ApplicationController
  before_action :doorkeeper_authorize!, if: ->{ authenticate_with_oauth? }
  before_filter :authenticate_user!, unless: ->{ authenticated_with_oauth? }
  before_filter :load_controlled_terms_resource, only: [:update, :destroy]

  def create
    p = controlled_terms_resource_params(params[:controlled_terms_resource])
    @controlled_terms_resource = ControlledTermsResource.new(p)
    if @controlled_terms_resource.save
        redirect_to @controlled_terms_resource.resource
    else
      respond_to do |format|
        format.json do
          render status: :unprocessable_entity,
            json: { errors: @controlled_terms_resource.errors.full_messages }
        end
      end
    end
  end

  def destroy
    @controlled_terms_resource.destroy
    redirect_to @controlled_terms_resource.resource
  end

  private
  def load_controlled_terms_resource
    @controlled_terms_resource = ControlledTermsResource.find_by_id(params[:id])
    render_404 unless @controlled_terms_resource
  end

  def controlled_terms_resource_params(p)
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
