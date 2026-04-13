# frozen_string_literal: true

class WelcomeController < ApplicationController
  HEADER_UTM = "utm_source=inaturalist_homepage&utm_campaign=homepage_redesign_2026".freeze

  before_action :set_homepage_wiki, only: :index

  prepend_around_action :enable_replica, only: [:index]

  def index
    respond_to do | format |
      format.html do
        @announcements = Announcement.active_in_placement( Announcement::WELCOME_INDEX, { site: @site } )
        @google_webmaster_verification = @site.google_webmaster_verification if @site

        # Admin preview: logged-in admins on the default site see the new homepage
        if @site == Site.default && logged_in? && current_user.is_admin?
          setup_v2_homepage
          render template: "welcome_v2/index", layout: "bootstrap"
          return
        end

        if logged_in? && !@site.draft?
          redirect_to home_path
        elsif !@page
          render layout: "bootstrap"
        end
      end
    end
  end

  private

  def set_homepage_wiki
    return unless @site

    # use a custom wiki page for this locale
    path = @site.home_page_wiki_path_by_locale( I18n.locale )
    if path
      @page = WikiPage.find_by_path( path )
      return
    end

    # otherwise use the site default wiki page
    path = @site.home_page_wiki_path
    @page = WikiPage.find_by_path( path ) if path
  end

  def setup_v2_homepage
    @responsive = true
    @skip_external_connections = true
    @skip_react = true

    @store_url = "https://tr.ee/MymHMn"
    @header_utm = HEADER_UTM
    @header_donate_url = "#{donate_path}?redirect=true&segment=gmHome&#{HEADER_UTM}&utm_medium=webmobile&utm_content=header_donate_cta"
    @header_login_url  = "#{login_path}?#{HEADER_UTM}&utm_medium=owned_web&utm_content=header_login_cta"
    @header_signup_url = "#{signup_path}?#{HEADER_UTM}&utm_medium=owned_web&utm_content=header_signup_cta"

    @locale_key = I18n.locale.to_s
    @locale_base = @locale_key.split( "-" ).first

    @story_data = Site.homepage_story_data( locale_key: @locale_key, locale_base: @locale_base )
    observations_data = Site.homepage_observation_data
    @sample_observation_data = observations_data["sample"]
    @sample_observation_common_name = @sample_observation_data["common_names"][@locale_key] ||
      @sample_observation_data["common_names"][@locale_base] ||
      @sample_observation_data["common_names"]["en"]
    @explore_observations_data = observations_data["explore"] || []
  end
end
