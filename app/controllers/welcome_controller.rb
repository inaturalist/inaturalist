class WelcomeController < ApplicationController
  MOBILIZED = [:index]
  before_filter :unmobilized, :except => MOBILIZED
  before_filter :mobilized, :only => MOBILIZED
  
  caches_action :index, :expires_in => 15.minutes, :if => Proc.new {|c|
    !c.send(:logged_in?) && 
    c.send(:flash).blank? && 
    c.request.format != :mobile
  }
  
  def index
    respond_to do |format|
      format.html do
        @announcement = Announcement.last(:conditions => [
         'placement = \'welcome/index\' AND ? BETWEEN "start" AND "end"', Time.now.utc])
        @observations_cache_key = "#{SITE_NAME}_#{I18n.locale}_welcome_observations"
        unless fragment_exist?(@observations_cache_key)
          @observations = Observation.has_geo.has_photos
                                     .includes([ :taxon,
                                                 :stored_preferences,
                                                 { :observation_photos => :photo },
                                                 { :user => :stored_preferences } ])
                                     .limit(4)
                                     .order("observations.id DESC").scoped
          if CONFIG.site_only_observations && params[:site].blank?
            @observations = @observations.where("observations.uri LIKE ?", "#{FakeView.root_url}%")
          elsif (site_bounds = CONFIG.bounds) && params[:swlat].blank?
            @observations = @observations.in_bounding_box(site_bounds['swlat'], site_bounds['swlng'], site_bounds['nelat'], site_bounds['nelng'])
          end
        end
        @page = WikiPage.find_by_path(CONFIG.home_page_wiki_path) if CONFIG.home_page_wiki_path
      end
      format.mobile
    end
  end
  
  def toggle_mobile
    session[:mobile_view] = session[:mobile_view] ? false : true
    redirect_to params[:return_to] || session[:return_to] || "/"
  end

end
