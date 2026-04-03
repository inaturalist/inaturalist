# frozen_string_literal: true

class WelcomeV2Controller < ApplicationController
  unless defined?( OBSERVATIONS_DATA )
    OBSERVATIONS_DATA = JSON.parse(
      File.read( Rails.root.join( "app/assets/images/welcome_v2/observations/observations.json" ) )
    ).freeze
  end

  def index
    @responsive = true
    @skip_external_connections = true
    @skip_react = true
    @explore_observations = OBSERVATIONS_DATA["explore"] || []
    @sample_observation   = OBSERVATIONS_DATA["sample"]
    @story_common_names   = OBSERVATIONS_DATA["stories"] || {}
    @locale_key           = I18n.locale.to_s
    @locale_base          = @locale_key.split( "-" ).first

    render layout: "bootstrap"
  end
end
