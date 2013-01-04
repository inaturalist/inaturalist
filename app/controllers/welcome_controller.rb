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
    @announcement = Announcement.last(:conditions => [
     'placement = \'welcome/index\' AND ? BETWEEN "start" AND "end"', Time.now.utc])
    scope = Observation.has_geo.has_photos.includes(:observation_photos => :photo).
      limit(4).order("observations.id DESC").scoped
    if INAT_CONFIG['site_only_observations']
      scope = scope.where("observations.uri LIKE ?", "#{root_url}%")
    end
    @observations = scope
    respond_to do |format|
      format.html
      format.mobile
    end
  end
  
  def toggle_mobile
    session[:mobile_view] = session[:mobile_view] ? false : true
    redirect_to params[:return_to] || session[:return_to] || "/"
  end

end
