# frozen_string_literal: true

class ComputerVisionEvalController < ApplicationController
  before_action :authenticate_user!
  before_action :admin_required

  def index
    render layout: "basic"
  end
end
