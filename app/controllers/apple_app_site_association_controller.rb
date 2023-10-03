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
    unless ( team_id = CONFIG&.apple&.team_id )
      return render_404 if response.blank?

      return render json: response
    end

    applinks_details = []

    # Newer-style way of specifying paths
    if ( applinks = CONFIG&.apple&.applinks2 )
      applinks_details += applinks.map do | applink |
        {
          appIDs: applink["bundle_ids"].map {| bundle_id | "#{team_id}.#{bundle_id}" },
          components: applink["components"].map do | config_component |
            component = { "/": config_component["path"] }
            component["?"] = config_component["query"].as_json unless config_component["query"].blank?
            component["#"] = config_component["fragment"].as_json unless config_component["fragment"].blank?
            component[:exclude] = true if config_component["exclude"].yesish?
            component[:comment] = config_component["comment"] unless config_component["comment"].blank?
            component
          end
        }
      end
    end

    # Older-style way of specifying paths, maybe totally obsolete
    if ( applinks = CONFIG&.apple&.applinks )
      applinks_details += applinks.to_h.map do | bundle_id, paths |
        {
          appID: "#{team_id}.#{bundle_id}",
          paths: paths
        }
      end
    end
    return render_404 if applinks_details.blank?

    response[:applinks] = {
      apps: [],
      details: applinks_details
    }

    render json: response
  end
end
