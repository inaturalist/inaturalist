# frozen_string_literal: true

class WelcomeV2Controller < ApplicationController
  def index
    @responsive = true
    render layout: "bootstrap"
  end
end
