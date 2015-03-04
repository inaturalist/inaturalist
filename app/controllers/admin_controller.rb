#
# A collection of tools useful for administrators.
#
class AdminController < ApplicationController
  
  before_filter :authenticate_user!
  before_filter :admin_required
  before_filter :return_here, :only => [:stats, :index, :user_content]
  
  def stats
    @observation_weeks = Observation.where("EXTRACT(YEAR FROM created_at) = ?", Time.now.year).
      group("EXTRACT(WEEK FROM created_at)").count
    @observation_weeks_last_year = Observation.where("EXTRACT(YEAR FROM created_at) = ?", Time.now.year - 1).
      group("EXTRACT(WEEK FROM created_at)").count
    @observations_max = (@observation_weeks.values + @observation_weeks_last_year.values).sort.last
    
    @user_weeks = User.where("EXTRACT(YEAR FROM created_at) = ?", Time.now.year).
      group("EXTRACT(WEEK FROM created_at)").count
    @user_weeks_last_year = User.where("EXTRACT(YEAR FROM created_at) = ?", Time.now.year - 1).
        group("EXTRACT(WEEK FROM created_at)").count
    @users_max = (@user_weeks.values + @user_weeks_last_year.values).sort.last
    
    @total_users = User.count
    @active_observers = Observation.where("created_at > ?", 3.months.ago).select("distinct user_id").count
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
        ST_Intersects(o.private_geom, pg.geom) 
        AND p.id = pg.place_id 
        AND o.created_at::DATE = '#{@daily_date.to_s}' 
        AND p.admin_level = #{Place::COUNTRY_LEVEL}
      GROUP BY p.display_name, p.code, p.id
    SQL
    @daily_country_stats = Observation.connection.execute(daily_country_stats_sql.gsub(/\s+/, ' ').strip)
  end
  
  def index
  end

  def user_content
    return unless load_user_content_info
    @records = @display_user.send(@reflection_name).page(params[:page]) rescue []
  end

  def update_user
    unless u = User.find_by_id(params[:id])
      flash[:error] = "User doesn't exist"
      redirect_back_or_default(curate_users_path)
    end
    u.update_attributes(params[:user])
    flash[:notice] = "User description deleted for #{u.login}"
    redirect_back_or_default(curate_users_path(:user_id => u.id))
  end

  def destroy_user_content
    return unless load_user_content_info
    @records = @display_user.send(@reflection_name).
      where("id IN (?)", params[:ids] || [])
    @records.each(&:destroy)
    flash[:notice] = "Deleted #{@records.size} #{@type.humanize.downcase}"
    redirect_back_or_default(admin_user_content_path(@display_user.id, @type))
  end
  
  def login_as
    unless user = User.find_by_id(params[:id] || [params[:user_id]])
      flash[:error] = "That user doesn't exist"
      redirect_back_or_default(:index)
    end
    sign_out :user
    sign_in user
    
    flash[:notice] = "Logged in as #{user.login}. Be careful, and remember to log out when you're done."
    redirect_to root_path
  end

  def delayed_jobs
    @jobs = Delayed::Job.all
  end
  

  private
  def load_user_content_info
    user_id = params[:id] || params[:user_id]
    @display_user = User.find_by_id(user_id)
    @display_user ||= User.find_by_login(user_id)
    @display_user ||= User.find_by_email(user_id)
    unless @display_user
      flash[:error] = "User #{user_id} doesn't exist"
      redirect_back_or_default(:action => "index")
      return false
    end

    @type = params[:type] || "observations"
    @reflection_name, @reflection = User.reflections.detect{|k,r| k.to_s == @type}
    @klass = Object.const_get(@reflection.class_name) rescue nil
    @klass = nil unless @klass.try(:base_class).try(:superclass) == ActiveRecord::Base
    unless @klass
      flash[:error] = "#{params[:type]} doesn't exist"
      redirect_back_or_default(:action => "index")
      return false
    end

    @reflection_names = []
    has_many_reflections = User.reflections.select{|k,v| v.macro == :has_many}
    has_many_reflections.each do |k, reflection|
      # Avoid those pesky :through relats
      next unless reflection.klass.column_names.include?(reflection.foreign_key)
      @reflection_names << k.to_s
    end
    @reflection_names.uniq!
    true
  end
end
