class WelcomeController < ApplicationController
  MOBILIZED = [:index]
  before_filter :unmobilized, :except => MOBILIZED
  before_filter :mobilized, :only => MOBILIZED
  before_filter :set_homepage_wiki, only: :index

  def index
    respond_to do |format|
      format.html do
        @announcement = Announcement.where(placement: "welcome/index").
          where('? BETWEEN "start" AND "end"', Time.now.utc).last
        @google_webmaster_verification = @site.google_webmaster_verification if @site
        unless @page
          if logged_in?
            redirect_to home_path
          else
            render layout: 'bootstrap'
          end
        end
      end
      format.mobile
    end
  end

  def toggle_mobile
    session[:mobile_view] = session[:mobile_view] ? false : true
    redirect_to params[:return_to] || session[:return_to] || "/"
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
