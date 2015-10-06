class WelcomeController < ApplicationController
  MOBILIZED = [:index]
  before_filter :unmobilized, :except => MOBILIZED
  before_filter :mobilized, :only => MOBILIZED
  before_filter :set_homepage_wiki, only: :index

  def index
    respond_to do |format|
      format.html do
        @announcement = Announcement.where('placement = \'welcome/index\' AND ? BETWEEN "start" AND "end"', Time.now.utc).last
        @observations_cache_key = "#{SITE_NAME}_#{I18n.locale}_welcome_observations"
        unless fragment_exist?(@observations_cache_key)
          @observations = load_observations_with_geo_and_good_photos
        end
        @google_webmaster_verification = @site.google_webmaster_verification if @site
        unless @page
          render layout: 'bootstrap'
        end
      end
      format.mobile
    end
  end

  def load_observations_with_geo_and_good_photos(number_to_load = 4)
    params = { with_photos: true, with_geo: true, per_page: number_to_load }
    observations = Observation.elastic_query(params, site: @site)
    observations
  end

  def toggle_mobile
    session[:mobile_view] = session[:mobile_view] ? false : true
    redirect_to params[:return_to] || session[:return_to] || "/"
  end

  private

  def set_homepage_wiki
    # use a custom wiki page for this locale
    if CONFIG.home_page_wiki_path_by_locale
      if path = CONFIG.home_page_wiki_path_by_locale.send( I18n.locale )
        @page = WikiPage.find_by_path( path )
      end
    end
    # otherwise use the site default wiki page
    if @page.blank? && CONFIG.home_page_wiki_path
      @page = WikiPage.find_by_path( CONFIG.home_page_wiki_path )
    end
  end

end
