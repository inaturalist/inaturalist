class ComputerVisionDemoController < ApplicationController
  before_filter :authenticate_user!

  def index
    render layout: "basic"
  end

end
