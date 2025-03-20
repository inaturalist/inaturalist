# frozen_string_literal: true

class WelcomeController < ApplicationController
  before_action :set_homepage_wiki, only: :index

  prepend_around_action :enable_replica, only: [:index]

  def index
    respond_to do | format |
      format.html do
        @announcements = Announcement.active_in_placement( Announcement::WELCOME_INDEX, { site: @site } )
        @google_webmaster_verification = @site.google_webmaster_verification if @site
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
end
