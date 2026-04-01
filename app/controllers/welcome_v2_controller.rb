# frozen_string_literal: true

class WelcomeV2Controller < ApplicationController
  # TODO: load and freeze observations as constant on controller initialization?

  def index
    @responsive = true
    @skip_external_connections = true
    @skip_react = true
    data = JSON.parse(
      File.read( Rails.root.join( "app/assets/images/welcome_v2/observations/observations.json" ) )
    )
    if data.is_a?( Array )
      @explore_observations = data
    else
      @explore_observations = data["explore"] || []
      @sample_observation   = data["sample"]
      @story_common_names   = data["stories"] || {}
    end
    render layout: "bootstrap"
  end
end
