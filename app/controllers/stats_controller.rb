class StatsController < ApplicationController

  before_filter :set_time_zone_to_utc
  before_filter :load_params
  caches_action :summary, expires_in: 1.hour
  caches_action :observation_weeks_json, expires_in: 1.day
  caches_action :nps_bioblitz, expires_in: 5.minutes

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
    params = { verifiable: true, per_page: 1 }
    params[:place_id] = @site.place_id if @site.place_id
    observations = INatAPIService.observations(params)
    observers = INatAPIService.observations_observers(params)
    species_counts = INatAPIService.observations_species_counts(params)
    user_count_scope = User.where("suspended_at IS NULL")
    if @site.name != "iNaturalist.org"
      user_count_scope = user_count_scope.where(site_id: @site.id)
    end
    @stats = {
      total_users: user_count_scope.count,
      total_leaf_taxa: (species_counts && species_counts.total_results) || 0,
      total_observations: (observations && observations.total_results) || 0,
      total_observed_taxa: (species_counts && species_counts.total_results) || 0,
      total_observers: (observers && observers.total_results) || 0,
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

  private
  def project_slideshow_data( overall_project_id, options = {} )
    umbrella_project_ids = options[:umbrella_project_ids] || []
    sub_project_ids = options[:sub_project_ids] || {}
    @overall_id = overall_project_id
    all_project_ids = (
      sub_project_ids.map{ |k,v| v }.flatten +
      sub_project_ids.keys +
      umbrella_project_ids +
      [overall_project_id]
    ).flatten.uniq

    projs = Project.select("projects.*, count(po.observation_id)").
      joins("LEFT JOIN project_observations po ON (projects.id=po.project_id)").
      group(:id).
      order("count(po.observation_id) desc")
    projs = if options[:group]
      projs.where("projects.group = ? OR projects.id = ? OR projects.id IN (?)", options[:group], params[:project_id], all_project_ids)
    else
      projs.where("projects.id = ? OR projects.id IN (?)", params[:project_id], all_project_ids)
    end

    # prepare the data needed for the slideshow
    begin
      all_project_data = Hash[ projs.map{ |p|
        [ p.id,
          {
            id: p.id,
            title: p.title.sub("2016 National Parks BioBlitz - ", ""),
            slug: p.slug,
            start_time: p.start_time,
            end_time: p.end_time,
            place_id: p.rule_place.try(:id),
            observation_count: p.count,
            in_progress: p.event_in_progress?,
            species_count: p.node_api_species_count
          }
        ]
      }]
    rescue
      sleep(2)
      return redirect_to :nps_bioblitz_stats
    end

    if block_given?
      yield all_project_data
    end

    # setting the number of slides to show per umbrella project
    umbrella_project_ids.each do |id|
      all_project_data[id][:slideshow_count] = 1 if all_project_data[id]
    end

    if all_project_data[@overall_id]
      # the overall project shows 5 slides
      all_project_data[@overall_id][:title] = options[:title]
      all_project_data[@overall_id][:slideshow_count] = 5
      # the overall project shows any non-umbrella project not already
      # shown under an umbrella project
      sub_project_ids[@overall_id] = all_project_data.keys -
        all_project_ids - sub_project_ids.keys
    end

    # deleting any empty umbrella projects
    @umbrella_projects = umbrella_project_ids.
      map{ |id| all_project_data[id] }.compact
    if options[:trim_slackers]
      @umbrella_projects = @umbrella_projects.delete_if{ |p| p[:observation_count] == 0 }
    end
    Rails.logger.debug "[DEBUG] @umbrella_projects: #{@umbrella_projects}"

    # randomizing subprojects
    @sub_projects = Hash[ sub_project_ids.map{ |umbrella_id,subproject_ids|
      [ umbrella_id, subproject_ids.shuffle.map{ |id| all_project_data[id] }.compact ]
    } ]

    @all_sub_projects = all_project_data.reject{ |k,v| @sub_projects[k] }.values
    @logo_paths = options[:logo_paths] || []

    render "project_slideshow", layout: "basic"
  end
  public

  def nps_bioblitz
    @overall_id = 6810
    umbrella_project_ids = [ 6810, 7109, 7110, 7107, 6790 ]
    sub_project_ids = {
      6810 => [ ],
      7109 => [ 6818, 6846, 6864, 7026, 6832, 7069, 6859 ],
      7110 => [ 6835, 6833, 6840, 7298, 6819, 7299, 6815,
        6814, 7025, 7281, 6816, 7302, 7301, 6822 ],
      7107 => [ 6824, 6465, 6478 ],
      6790 => [ 6850, 6851, 7167, 6852, 7168, 7169 ]
    }
    project_slideshow_data( @overall_id, {
      umbrella_project_ids: umbrella_project_ids,
      sub_project_ids: sub_project_ids,
      trim_slackers: true,
      group: Project::NPS_BIOBLITZ_GROUP_NAME,
      title: "NPS Servicewide",
      logo_paths: ["/logo-nps.svg", "/logo-natgeo.svg"]
    } ) do |all_project_data|
      # hard-coding umbrella project places
      all_project_data[6810][:place_id] = 0 if all_project_data[6810]
      all_project_data[7109][:place_id] = 46 if all_project_data[7109]
      all_project_data[7110][:place_id] = 5 if all_project_data[7110]
      all_project_data[7107][:place_id] = 51727 if all_project_data[7107]
      all_project_data[6790][:place_id] = 43 if all_project_data[6790]
    end
  end

  def cnc2017
    project_slideshow_data( 11753,
      umbrella_project_ids: [11753],
      sub_project_ids: {
        11753 => [10931, 11013, 11053, 11126, 10768, 10769, 10752, 10764, 11047, 11110, 10788, 10695, 10945, 10917, 10763, 11042]
      },
      title: "City Nature Challenge 2017"
    )
  end

  def cnc2016
    project_slideshow_data( 6365,
      umbrella_project_ids: [6365, 6345],
      title: "City Nature Challenge 2016"
    )
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
