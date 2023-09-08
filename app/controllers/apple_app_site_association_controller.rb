# frozen_string_literal: true

# https://developer.apple.com/documentation/xcode/supporting-associated-domains
class AppleAppSiteAssociationController < ApplicationController
  def index
    response = {}
    unless @site.preferred_ios_app_webcredentials.blank?
      response[:webcredentials] = {
        apps: @site.preferred_ios_app_webcredentials.to_s.split( "," )
      }
    end
    if ( applinks = CONFIG&.apple&.applinks ) && ( team_id = CONFIG&.apple&.team_id )
      details = applinks.to_h.map do | bundle_id, paths |
        {
          appID: "#{team_id}.#{bundle_id}",
          paths: paths
        }
      end
      response[:applinks] = {
        apps: [],
        details: details
      }
    end
    return render_404 if response.blank?

    render json: response
  end
end
