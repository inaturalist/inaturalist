#
# A collection of tools useful for administrators.
#
class AdminController < ApplicationController
  
  before_filter :login_required
  before_filter :admin_required
  
  def stats
    @observation_weeks = Observation.count(
      :conditions => ["EXTRACT(YEAR FROM created_at) = ?", Time.now.year],
      :group => "EXTRACT(WEEK FROM created_at)"
    )
    @observation_weeks_last_year = Observation.count(
      :conditions => ["EXTRACT(YEAR FROM created_at) = ?", Time.now.year - 1],
      :group => "EXTRACT(WEEK FROM created_at)"
    )
    @observations_max = (@observation_weeks.values + @observation_weeks_last_year.values).sort.last
    
    @user_weeks = User.count(
      :conditions => ["EXTRACT(YEAR FROM created_at) = ?", Time.now.year],
      :group => "EXTRACT(WEEK FROM created_at)"
    )
    @user_weeks_last_year = User.count(
      :conditions => ["EXTRACT(YEAR FROM created_at) = ?", Time.now.year - 1],
      :group => "EXTRACT(WEEK FROM created_at)"
    )
    @users_max = (@user_weeks.values + @user_weeks_last_year.values).sort.last
    
    @total_users = User.count
    @active_observers = Observation.count(:select => "distinct user_id", :conditions => ["created_at > ?", 3.months.ago])
    @total_observations = Observation.count
  end
  
  def index
  end
  
end
