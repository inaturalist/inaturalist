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
    if ( applinks = CONFIG&.apple&.applinks2 ) && ( team_id = CONFIG&.apple&.team_id )
      details = applinks.map do | applink |
        {
          appIDs: applink["bundle_ids"].map {| bundle_id | "#{team_id}.#{bundle_id}" },
          components: applink["components"].map do | component |
            {
              "/": component["path"],
              exclude: component["exclude"].yesish?,
              comment: component["comment"]
            }
          end
        }
      end
      response[:applinks] = { details: details }
    elsif ( applinks = CONFIG&.apple&.applinks ) && ( team_id = CONFIG&.apple&.team_id )
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
