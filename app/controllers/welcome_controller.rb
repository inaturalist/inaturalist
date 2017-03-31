class WelcomeController < ApplicationController
  before_filter :set_homepage_wiki, only: :index

  def index
    respond_to do |format|
      format.html do
        @announcement = Announcement.where(placement: "welcome/index").
          where('? BETWEEN "start" AND "end"', Time.now.utc).last
        @google_webmaster_verification = @site.google_webmaster_verification if @site
        
        if logged_in?
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
