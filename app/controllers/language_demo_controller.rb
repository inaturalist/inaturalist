# frozen_string_literal: true

class LanguageDemoController < ApplicationController
  before_action :authenticate_user!
  before_action :admin_required

  def index
    render layout: "basic"
  end

  def record_votes
    log = LanguageDemoLog.create( params[:language_demo_log] )
    if log.save
      head :ok
    else
      render status: :unprocessable_entity, json: { errors: log.errors.as_json }
    end
  end
end
