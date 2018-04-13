class WelcomeController < ApplicationController
  before_filter :set_homepage_wiki, only: :index

  def index
    respond_to do |format|
      format.html do
        scope = Announcement.
          where(placement: "welcome/index").
          where('? BETWEEN "start" AND "end"', Time.now.utc).
          limit( 5 )
        base_scope = scope
        scope = scope.where( site_id: nil )
        @announcements = scope.in_locale( I18n.locale )
        @announcements = scope.in_locale( I18n.locale.to_s.split('-').first ) if @announcements.blank?
        if @announcements.blank?
          @announcements = base_scope.where( "site_id = ? AND locales IN (?)",  @site, [] )
          @announcements << base_scope.in_locale( I18n.locale ).where( site_id: @site )
          @announcements = @announcements.flatten
        end
        @google_webmaster_verification = @site.google_webmaster_verification if @site
        
        if logged_in? && !@site.draft?
          redirect_to home_path
        elsif !@page
          render layout: 'bootstrap'
        end
      end
    end
  end

  private

  def set_homepage_wiki
    if @site
      # use a custom wiki page for this locale
      if path = @site.home_page_wiki_path_by_locale( I18n.locale )
        @page = WikiPage.find_by_path( path )
      end
      # otherwise use the site default wiki page
      if @page.blank? && ( path = @site.home_page_wiki_path )
        @page = WikiPage.find_by_path( path )
      end
    end
  end

end
