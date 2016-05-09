class StatsController < ApplicationController

  before_filter :set_time_zone_to_utc
  before_filter :load_params
  caches_action :summary, expires_in: 1.hour
  caches_action :observation_weeks_json, expires_in: 1.day

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

  def observation_weeks
    render layout: "basic"
  end

  def observation_weeks_json
    render json: observation_weeks_data
  end

  def bioblitz
    if project = Project.find_by_id(params[:project_id])
      @project_id = project.id
      @project_title = project.title
      @place_id = project.rule_place.try(:id)
    end
    render layout: "basic"
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

  def observation_weeks_data
    inner1 = "
      SELECT
        date_trunc( 'week', o.created_at ) AS week,
        user_id,
        count(*) as user_total,
        count(*) over( partition by date_trunc( 'week', o.created_at ) ) as observer_count
      FROM observations o
      WHERE quality_grade IN ( 'research', 'needs_id' )
      GROUP BY date_trunc( 'week', o.created_at ), user_id"
    inner2 = "
      SELECT
        week,
        user_id,
        user_total,
        observer_count,
        rank( ) OVER( partition by week order by user_total desc ) as user_rank,
        sum( user_total ) OVER( partition by week ) as week_total
      FROM (#{ inner1 }) as inner1"
    query = "
      SELECT
        week,
        user_id as id,
        u.login,
        u.icon_file_name,
        u.icon_content_type,
        u.icon_file_size,
        user_total,
        observer_count,
        week_total,
        rank( ) OVER( order by week_total desc ) as week_rank,
        rank( ) OVER( order by user_total desc ) as user_week_rank
      FROM (#{ inner2 }) as inner2
      LEFT JOIN users u ON ( inner2.user_id = u.id )
      WHERE user_rank = 1
      ORDER by week desc"
    weeks_totals = User.find_by_sql(query)
    weeks_totals.map do |r|
      {
        week: r.week,
        user_id: r.id,
        user_login: r.login,
        user_icon: r.medium_user_icon_url,
        user_week_total: r.user_total,
        user_week_rank: r.user_week_rank,
        week_total: r.week_total.to_i,
        week_rank: r.week_rank,
        observer_count: r.observer_count
      }
    end
  end

end
