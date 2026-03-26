# frozen_string_literal: true

class WelcomeV2Controller < ApplicationController
  def index
    @responsive = true
    @skip_external_connections = true
    @skip_react = true
    render layout: "bootstrap"
  end
end
