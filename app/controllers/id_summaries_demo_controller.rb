# frozen_string_literal: true

class IdSummariesDemoController < ApplicationController
  before_action :admin_required

  def index
    render layout: "basic"
  end
end
