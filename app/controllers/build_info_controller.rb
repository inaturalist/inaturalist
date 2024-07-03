# frozen_string_literal: true

class BuildInfoController < ApplicationController
  before_action :authenticate_user!
  before_action :admin_required

  def index
    build_info = {
      git_branch: ENV["GIT_BRANCH"] || "",
      git_commit: ENV["GIT_COMMIT"] || "",
      image_tag: ENV["IMAGE_TAG"] || "",
      build_date: ENV["BUILD_DATE"] || ""
    }
    render json: build_info
  end

  def app_build_info
    @app_build_info_json = INatAPIService.get(
      "/app_build_info",
      { authenticate: current_user },
      { endpoint: INatAPIService::ENDPOINT.sub( "v1", "v2" ) }
    )
    respond_to do | format |
      format.json { render json: @app_build_info_json }
      format.html { render template: "admin/app_build_info", layout: "admin" }
    end
  end
end
