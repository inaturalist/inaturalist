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
    
    @daily_date = Date.yesterday
    daily_country_stats_sql = <<-SQL
      SELECT 
        p.display_name, p.code, p.id, count(o.*)
      FROM 
        observations o, 
        places p, 
        place_geometries pg
      WHERE 
        ST_Intersects(o.geom, pg.geom) 
        AND p.id = pg.place_id 
        AND o.created_at::DATE = '#{@daily_date.to_s}' 
        AND p.place_type = 12 
      GROUP BY p.display_name, p.code, p.id
    SQL
    @daily_country_stats = Observation.connection.execute(daily_country_stats_sql.gsub(/\s+/, ' ').strip)
  end
  
  def index
  end
  
  def login_as
    unless user = User.find_by_id(params[:id] || [params[:user_id]])
      flash[:error] = "That user doesn't exist"
      redirect_back_or_default(:index)
    end
    logout_keeping_session!
    self.current_user = user
    
    flash[:notice] = "Logged in as #{user.login}. Be careful, and remember to log out when you're done."
    redirect_to root_path
  end
  
end
