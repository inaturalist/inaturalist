# frozen_string_literal: true

class ModeratorActionsController < ApplicationController
  before_action :authenticate_user!
  before_action :curator_required, except: [:resource_url]
  before_action :load_record, only: [:resource_url, :edit, :update]
  before_action :resource_must_be_viewable_by_logged_in_user, only: [:resource_url]
  before_action :editor_required, only: [:edit, :update]

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
            when ModeratorAction::HIDE then t( :identification_hidden )
            when ModeratorAction::UNHIDE then t( :identification_unhidden )
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
          when "Photo"
            case @moderator_action.action
            when ModeratorAction::HIDE then t( :photo_hidden )
            when ModeratorAction::UNHIDE then t( :photo_unhidden )
            else default_notice
            end
            redirect_to @moderator_action.resource.becomes( Photo )
            return
          when "Sound"
            case @moderator_action.action
            when ModeratorAction::HIDE then t( "sounds.sound_hidden" )
            when ModeratorAction::UNHIDE then t( "sounds.sound_unhidden" )
            else default_notice
            end
            redirect_to @moderator_action.resource.becomes( Sound )
            return
          else
            default_notice
          end
          redirect_to @moderator_action.resource
        end
      else
        format.json do
          render status: :unprocessable_entity, json: { errors: @moderator_action.errors }
        end
        format.html do
          flash[:error] =
            t( :failed_to_save_record_with_errors, errors: @moderator_action.errors.full_messages.to_sentence )
          if @moderator_action.resource_type == "Comment"
            redirect_to hide_comment_path( @moderator_action.resource )
            return
          end
          if @moderator_action.resource_type == "Photo"
            redirect_to hide_photo_path( @moderator_action.resource )
            return
          end
          if @moderator_action.resource_type == "Sound"
            redirect_to hide_sound_path( @moderator_action.resource )
            return
          end
          if @moderator_action.resource_type == "User" && @moderator_action.action == ModeratorAction::SUSPEND
            @user = @moderator_action.resource
            render "users/suspend", layout: "bootstrap"
            return
          end
          redirect_back( fallback_location: @moderator_action.resource )
        end
      end
    end
  end

  def edit
    render layout: "bootstrap"
  end

  def update
    @moderator_action.last_edited_by_user = current_user
    if @moderator_action.update( approved_update_params )
      flash[:notice] = t( :updated )
      redirect_to moderation_person_path( @moderator_action.resource )
    else
      flash[:error] = t( :failed_to_save_record_with_errors,
        errors: @moderator_action.errors.full_messages.to_sentence )
      render :edit, layout: "bootstrap"
    end
  end

  def resource_url
    url = case @moderator_action.resource_type
    when "Photo"
      @moderator_action.resource.presigned_url( params[:size] || "original" )
    when "Sound"
      if @moderator_action.resource.is_a?( SoundcloudSound )
        @moderator_action.resource.native_page_url
      else
        @moderator_action.resource.presigned_url
      end
    end
    render json: { resource_url: url }
  end

  protected

  def editor_required
    return if @moderator_action.editable_by?( current_user )

    flash[:error] = t( :you_dont_have_permission_to_do_that )
    redirect_back_or_default( root_url )
  end

  def approved_params
    params.require( :moderator_action ).permit(
      :reason,
      :action,
      :resource_type,
      :resource_id,
      :private,
      :suspended_until
    )
  end

  def approved_update_params
    params.require( :moderator_action ).permit( :reason, :suspended_until )
  end

  def resource_must_be_viewable_by_logged_in_user
    return if @moderator_action.resource.hidden_content_viewable_by?( current_user )

    msg = if @moderator_action.private?
      t( :only_administrators_may_access_that_page )
    else
      t( :only_curators_can_access_that_page )
    end
    respond_to do | format |
      format.html do
        flash[:error] = msg
        redirect_back_or_default( root_url )
      end
      format.js do
        render status: :unprocessable_entity, plain: msg
      end
      format.json do
        render status: :unprocessable_entity, json: { error: msg }
      end
    end
  end
end
