#
# A collection of tools useful for administrators.
#
class AdminController < ApplicationController
  
  before_filter :login_required
  before_filter :admin_required
  
  def stats
    @observation_weeks = Observation.count(
      :conditions => ["YEAR(created_at) = ?", Time.now.year],
      :group => "WEEK(created_at)"
    )
    @observation_weeks_last_year = Observation.count(
      :conditions => ["YEAR(created_at) = ?", Time.now.year - 1],
      :group => "WEEK(created_at)"
    )
    @observations_max = (@observation_weeks.values + @observation_weeks_last_year.values).sort.last
    
    @user_weeks = User.count(
      :conditions => ["YEAR(created_at) = ?", Time.now.year],
      :group => "WEEK(created_at)"
    )
    @user_weeks_last_year = User.count(
      :conditions => ["YEAR(created_at) = ?", Time.now.year - 1],
      :group => "WEEK(created_at)"
    )
    @users_max = (@user_weeks.values + @user_weeks_last_year.values).sort.last

  end
  
  def index
  end
  
end
