class WelcomeController < ApplicationController
  before_filter :set_homepage_wiki, only: :index

  def index
    respond_to do |format|
      format.html do
        scope = Announcement.
          where(placement: "welcome/index").
          where('? BETWEEN "start" AND "end"', Time.now.utc).
          joins( "LEFT OUTER JOIN announcements_sites ON announcements_sites.announcement_id = announcements.id").
          joins( "LEFT OUTER JOIN sites ON sites.id = announcements_sites.site_id" ).
          limit( 5 )
        base_scope = scope
        scope = scope.where( "sites.id IS NULL OR sites.id = ?", @site )
        @announcements = scope.in_locale( I18n.locale )
        @announcements = scope.in_locale( I18n.locale.to_s.split('-').first ) if @announcements.blank?
        if @announcements.blank?
          @announcements = base_scope.where( "sites.id IS NULL AND locales IN (?)", [] )
          @announcements << base_scope.in_locale( I18n.locale ).where( "sites.id IS NULL" )
          @announcements = @announcements.flatten
        end
        @announcements = @announcements.sort_by {|a| [
          a.site_ids.include?( @site.try(:id) ) ? 0 : 1,
          a.locales.include?( I18n.locale ) ? 0 : 1,
          a.id * -1
        ] }
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
