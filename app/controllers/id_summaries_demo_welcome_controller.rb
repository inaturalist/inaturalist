# frozen_string_literal: true

class IdSummariesDemoWelcomeController < ApplicationController
  def index
    @welcome_stylesheet = "id_summaries_demo_welcome"
    respond_to do | format |
      format.html do
        render layout: "bootstrap"
      end
    end
  end
end
