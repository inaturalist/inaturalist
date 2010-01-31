class WelcomeController < ApplicationController
  def index
    @observations = Observation.find(:all, 
      :include => :photos,
      :limit => 4,
      :order => "observations.created_at DESC",
      :conditions => "latitude IS NOT NULL AND longitude IS NOT NULL " + 
                     "AND photos.id IS NOT NULL")
    @first_goal_total = Observation.count
  end
  
  def toggle_mobile
    session[:mobile_view] = session[:mobile_view] ? false : true
    redirect_to params[:return_to] || session[:return_to] || "/"
  end
end
