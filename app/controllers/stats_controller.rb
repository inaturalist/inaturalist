class StatsController < ApplicationController

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
    @end_date = Time.zone.parse(params[:end_date]).beginning_of_day rescue Time.now
    @start_date = Time.zone.parse(params[:start_date]).beginning_of_day rescue 1.day.ago
    @start_date = Time.zone.now if @start_date > Time.zone.now
    @end_date = Time.zone.now if @end_date > Time.zone.now
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
