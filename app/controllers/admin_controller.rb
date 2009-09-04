#
# A collection of tools useful for administrators.
#
class AdminController < ApplicationController
  
  before_filter :login_required
  before_filter :admin_required
  
  def stats
    observations = Observation.find(:all,
           :select => "user_id, COUNT('id') AS weekly_count, WEEK(created_at) AS week",
           :conditions => ["YEAR(created_at) = ?", Time.now.year],
           :group => 'user_id, week',
           :order => 'user_id ASC, week ASC')

    @obs = {}
    observations.each do |observation|
      @obs[observation.user_id] = {:login => observation.user.login, :weeks => Array.new(52, 0)} unless @obs.has_key?(observation.user_id)
      @obs[observation.user_id][:weeks][observation.week.to_i] = observation.weekly_count
    end
  end
  
  def index
  end
  
  private
  
  def admin_required
    unless current_user.has_role? :admin
      flash[:notice] = "Only Administrators may access that page"
      redirect_to observations_path
    end
  end
  
end
