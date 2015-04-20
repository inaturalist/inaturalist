class SoundcloudSoundsController < ApplicationController

  def index
    params[:limit] ||= 5
    params[:offset] ||= 0
    if client = SoundcloudSound.client_for_user(current_user)
      begin
        api_sounds = client.get('/me/tracks', :limit => params[:limit], :offset => params[:offset])
        @sounds = api_sounds.map{|s| SoundcloudSound.new_from_api_response(s)}
      rescue Soundcloud::ResponseError => e
        if e.message =~ /Unauthorized/
          @reauthorization_needed = true
        elsif e.message =~ /Internal Server Error/
          @soundcloud_error = true
        else
          raise e
        end
      end
    end
    render :partial => 'sounds/sound_list_form', :locals => {:sounds => @sounds, :index => params[:index]}
  end

end