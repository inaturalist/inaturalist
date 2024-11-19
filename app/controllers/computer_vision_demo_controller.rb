# frozen_string_literal: true

class ComputerVisionDemoController < ApplicationController
  before_action :authenticate_user!

  def index
    render layout: "basic"
  end
end
