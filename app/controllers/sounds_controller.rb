# frozen_string_literal: true

class SoundsController < ApplicationController
  before_action :doorkeeper_authorize!, only: [:create, :update],
    if: -> { authenticate_with_oauth? }
  before_action :load_record, only: [:show, :update, :destroy, :hide]
  before_action :require_owner, only: [:update, :destroy]
  before_action :authenticate_user!, except: [:show],
    unless: -> { authenticated_with_oauth? }
  before_action :curator_required, only: [:hide]

  prepend_around_action :enable_replica, only: [:show]

  def show
    respond_to do | format |
      format.html do
        @observations = @sound.observations.limit( 100 )
        @flags = @sound.flags
      end
    end
  end

  def create
    @sound = if !params[:file].blank? && !params[:uuid].blank?
      LocalSound.where( "user_id = ? AND uuid = ?", current_user, params[:uuid] ).first
    end
    @sound ||= LocalSound.new
    @sound.assign_attributes(
      file: params[:file],
      user: current_user,
      uuid: params[:uuid]
    )
    respond_to do | format |
      if @sound.save
        @sound.reload
        format.html { redirect_to observations_path }
        format.json do
          json = @sound.as_json( include: {
            to_observation: {
              include: { observation_field_values:
                { include: :observation_field, methods: :taxon } }
            }
          } )
          json[:file_url] = @sound.file.url
          render json: json
        end
      else
        format.html { redirect_to observations_path }
        format.json { render json: { errors: @sound.errors }, status: :unprocessable_entity }
      end
    end
  end

  def update
    if @sound.update( sound_update_params( params[:sound] ) )
      respond_to do | format |
        format.html do
          flash[:notice] = t( :updated_sound )
          redirect_to @sound.becomes( Sound )
        end
        format.json do
          render json: @sound.as_json
        end
      end
    else
      respond_to do | format |
        format.html do
          flash[:error] = t( :error_updating_sound, sound_errors: @sound.errors.full_messages.to_sentence )
          redirect_to @sound.becomes( Sound )
        end
        format.json do
          render status: :unprocessable_entity, json: { errors: @sound.errors.as_json }
        end
      end
    end
  end

  def destroy
    resource = @sound.observations.first
    @sound.destroy
    flash[:notice] = t( "sounds.sound_deleted" )
    redirect_back_or_default( resource || "/" )
  end

  def hide
    @item = @sound
    render "moderator_actions/hide_content"
  end

  def local_sound_fields
    respond_to do | format |
      format.html do
        render partial: "sounds/sound_list_form", locals: {
          sounds: [],
          local_sounds: true,
          index: params[:index].to_i
        }
      end
    end
  end

  def require_owner
    return if logged_in? && @sound.editable_by?( current_user )

    msg = t( :you_dont_have_permission_to_do_that )
    respond_to do | format |
      format.html do
        flash[:error] = msg
        return redirect_to @sound.becomes( Sound )
      end
      format.json do
        return render json: { error: msg }, status: :forbidden
      end
    end
  end

  def sound_update_params( options = {} )
    p = options.blank? ? params : options
    allowed_fields = Sound::MASS_ASSIGNABLE_ATTRIBUTES + [:license, :license_code]
    p.permit( allowed_fields )
  end
end
