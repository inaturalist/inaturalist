# frozen_string_literal: true

class ModeratorActionsController < ApplicationController
  before_action :authenticate_user!
  before_action :curator_required

  def create
    @moderator_action = ModeratorAction.new( approved_params )
    @moderator_action.user = current_user
    respond_to do | format |
      if @moderator_action.save
        format.json { render json: @moderator_action }
        format.html do
          default_notice = "#{@moderator_action.resource_type.humanize}: #{@moderator_action.action}"
          flash[:notice] = case @moderator_action.resource_type
          when "Comment"
            case @moderator_action.action
            when ModeratorAction::HIDE then t( :comment_hidden )
            when ModeratorAction::UNHIDE then t( :comment_unhidden )
            else default_notice
            end
          when "Identification"
            case @moderator_action.action
            when ModeratorAction::HIDE then t( :identification_text_hidden )
            when ModeratorAction::UNHIDE then t( :identification_text_unhidden )
            else default_notice
            end
          when "User"
            case @moderator_action.action
            when ModeratorAction::SUSPEND
              t( :the_user_x_has_been_suspended, user: @moderator_action.resource.login )
            when ModeratorAction::UNSUSPEND
              t( :the_user_x_has_been_unsuspended, user: @moderator_action.resource.login )
            else default_notice
            end
          else
            default_notice
          end
          redirect_back_or_default @moderator_action.resource
        end
      else
        format.json do
          render status: :unprocessable_entity, json: { errors: @moderator_action.errors }
        end
        format.html do
          flash[:error] =
            t( :failed_to_save_record_with_errors, errors: @moderator_action.errors.full_messages.to_sentence )
          redirect_back_or_default @moderator_action.resource
        end
      end
    end
  end

  protected

  def approved_params
    params.require( :moderator_action ).permit(
      :reason,
      :action,
      :resource_type,
      :resource_id
    )
  end
end
