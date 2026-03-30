# frozen_string_literal: true

class WelcomeV2Controller < ApplicationController
  def index
    @responsive = true
    @skip_external_connections = true
    @skip_react = true
    @explore_observations = JSON.parse(
      File.read( Rails.root.join( "app/assets/images/welcome_v2/observations/observations.json" ) )
    )
    render layout: "bootstrap"
  end
end
