class SoundcloudSoundsController < ApplicationController

  def index
    client = SoundcloudSound.client_for_user(current_user)
    params[:limit] ||= 5
    params[:offset] ||= 0
    begin
      api_sounds = client.get('/me/tracks', :limit => params[:limit], :offset => params[:offset])
      @sounds = api_sounds.map{|s| SoundcloudSound.new_from_api_response(s)}
    rescue Soundcloud::ResponseError => e
      raise e unless e.message =~ /Unauthorized/
      @reauthorization_needed = true
    end
    render :partial => 'sounds/sound_list_form', :locals => {:sounds => @sounds, :index => params[:index]}
  end

end