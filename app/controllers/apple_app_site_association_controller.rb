class AppleAppSiteAssociationController < ApplicationController
  def index
    unless @site && !@site.preferred_ios_app_webcredentials.blank?
      render_404
      return
    end
    render :json => {
      webcredentials: {
        apps: [
          @site.preferred_ios_app_webcredentials
        ]
      }
    }
  end
end
