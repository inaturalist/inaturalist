class ModeratorActionsController < ApplicationController
  before_filter :authenticate_user!
  before_filter :curator_required

  def create
    @moderator_action = ModeratorAction.new( approved_params )
    @moderator_action.user = current_user
    respond_to do |format|
      if @moderator_action.save
        format.json { render json: @moderator_action }
        format.html do
          if @moderator_action == ModeratorAction::HIDE
            flash[:notice] = "comment hidden"
          else
            flash[:notice] = "comment unhidden"
          end
          redirect_back_or_default @moderator_action.resource
        end
      else
        format.json do
          render status: :unprocessable_entity, json: { errors: @moderator_action.errors }
        end
        format.html do
          flash[:error] = "Couldn't hide resource: #{@moderator_action.errors.full_messages.to_sentence}"
          redirect_back_or_default @moderator_action.resource
        end
      end
    end
  end

  protected

  def approved_params
    params.require(:moderator_action).permit(
      :reason,
      :action,
      :resource_type,
      :resource_id
    )
  end
end
