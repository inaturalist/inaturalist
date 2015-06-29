class Admin::StatsController < ApplicationController

  before_filter :authenticate_user!
  before_filter :admin_required
  before_filter :set_time_zone_to_utc
  before_filter :load_params
  before_filter :fetch_statistics, except: :index

  def index
    respond_to do |format|
      format.json {
        fetch_statistics
        render json: @stats, except: :id, callback: params[:callback]
      }
      format.html {
        if params[:start_date].nil?
          @start_date = @end_date - 1.year
        end
        fetch_statistics
        render layout: 'bootstrap'
      }
    end
  end

  private

  def set_time_zone_to_utc
    Time.zone = "UTC"
  end

  def load_params
    @end_date = Time.strptime(params[:end_date], "%Y-%m-%d") rescue Time.now
    @start_date = Time.strptime(params[:start_date], "%Y-%m-%d") rescue 1.day.ago
    @start_date = Time.now if @start_date > Time.now
    @end_date = Time.now if @end_date > Time.now
    if first_stat = SiteStatistic.order("created_at asc").first
      @start_date = first_stat.created_at if @start_date < first_stat.created_at
    end
  end

  def fetch_statistics
    @stats = SiteStatistic.where(created_at: @start_date..@end_date).order("created_at desc")
    unless @stats.any?
      @stats = [ SiteStatistic.order("created_at asc").last ]
    end
  end

end
