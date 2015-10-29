class StatsController < ApplicationController

  before_filter :set_time_zone_to_utc
  before_filter :load_params
  caches_action :summary, expires_in: 1.hour

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

  def summary
    fetch_statistics
    es_stats = Observation.elastic_search(size: 0,
      aggregate: {
        total_observations: { cardinality: { field: "id", precision_threshold: 10000 } },
        total_observed_taxa: { cardinality: { field: "taxon.id", precision_threshold: 10000 } },
        total_observers: { cardinality: { field: "user.id", precision_threshold: 10000 } }
      }).response.aggregations
    @stats = {
      total_users: User.where("suspended_at IS NULL").count,
      total_leaf_taxa: Observation.elastic_taxon_leaf_ids.size,
      total_observations: es_stats[:total_observations][:value],
      total_observed_taxa: es_stats[:total_observed_taxa][:value],
      total_observers: es_stats[:total_observers][:value],
      updated_at: Time.now
    }
    respond_to do |format|
      format.json { render json: @stats}
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
    if SiteStatistic.first_stat && @start_date < SiteStatistic.first_stat.created_at
      @start_date = SiteStatistic.first_stat.created_at
    end
  end

  def fetch_statistics
    @stats = SiteStatistic.where(created_at: @start_date..@end_date).order("created_at desc")
    unless @stats.any?
      @stats = [ SiteStatistic.order("created_at asc").last ]
    end
  end

end
