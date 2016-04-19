class ChartsController < ApplicationController
  before_filter :authenticate_user!

  caches_action :week_stats_json, expires_in: 1.day

  def week_stats
    render layout: "basic"
  end

  def week_stats_json
    render json: week_stats_data
  end

  def week_stats_data
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
