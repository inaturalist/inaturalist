class SoundsController < ApplicationController
  before_filter :authenticate_user!
  
  def local_sound_fields
    respond_to do |format|
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