# frozen_string_literal: true

class SoundsController < ApplicationController
  before_action :doorkeeper_authorize!, only: [:create],
    if: -> { authenticate_with_oauth? }
  before_action :authenticate_user!
  before_action :load_record, only: [:show]

  def show
    redirect_to @sound.observations.first
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
end
