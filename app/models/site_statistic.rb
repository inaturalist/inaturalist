class SiteStatistic < ActiveRecord::Base

  STAT_TYPES = [ :observations, :users, :projects,
    :taxa, :identifications, :identifier, :platforms, :platforms_cumulative ]

  def self.generate_stats_for_day(at_time = Time.now, options = {})
    at_time = at_time.utc.end_of_day
    if options[:force]
      SiteStatistic.where("DATE(created_at) = DATE(?)", at_time.utc).delete_all
    elsif stats_generated_for_day?(at_time)
      return
    end
    SiteStatistic.create({
      data: Hash[
        STAT_TYPES.map{ |st| [ st, send("#{ st }_stats", at_time) ] }
      ].to_json,
      created_at: at_time.beginning_of_day
    })
  end

  def self.generate_stats_for_date_range(start_time, end_time = Time.now, options = {})
    start_time = start_time.utc.end_of_day
    end_time = end_time.utc.end_of_day
    until end_time < start_time
      generate_stats_for_day(end_time, options)
      end_time -= 1.day
    end
  end

  def self.stats_generated_for_day?(at_time = Time.now)
    SiteStatistic.where("DATE(created_at) = DATE(?)", at_time.utc).exists?
  end

  def self.first_stat
    @@first_stat ||= SiteStatistic.order("created_at asc").first
  end

  private

  def self.observations_stats(at_time = Time.now)
    at_time = at_time.utc
    { count: Observation.where("created_at <= ?", at_time).count,
      research_grade: Observation.where("created_at <= ?", at_time).
        has_quality_grade(Observation::RESEARCH_GRADE).count,
      last_7_days: Observation.where("created_at BETWEEN ? AND ?", at_time - 7.days, at_time).count,
      today: Observation.where("created_at BETWEEN ? AND ?", at_time - 1.day, at_time).count,
      identified: Observation.where("taxon_id IS NOT NULL AND created_at BETWEEN ? AND ?", at_time - 7.days, at_time).count,
      community_identified: Observation.where("community_taxon_id IS NOT NULL AND created_at BETWEEN ? AND ?", at_time - 7.days, at_time).count,
      community_identified_to_genus: Observation.joins(:community_taxon).where("taxa.rank_level <= 20 AND observations.created_at BETWEEN ? AND ?", at_time - 7.days, at_time).count
    }
  end

  def self.identifications_stats(at_time = Time.now)
    at_time = at_time.utc
    { count: Identification.where("created_at <= ?", at_time).count,
      last_7_days: Identification.where("created_at BETWEEN ? AND ?", at_time - 7.days, at_time).count,
      today: Identification.where("created_at BETWEEN ? AND ?", at_time - 1.day, at_time).count
    }
  end

  def self.users_stats(at_time = Time.now)
    at_time = at_time.utc
    { count: User.where("created_at <= ?", at_time).count,
      curators: User.where("created_at <= ?", at_time).curators.count,
      admins: User.where("created_at <= ?", at_time).admins.count,
      active: User.active_ids(at_time).count,
      last_7_days: User.where("created_at BETWEEN ? AND ?", at_time - 7.days, at_time).count,
      today: User.where("created_at BETWEEN ? AND ?", at_time - 1.day, at_time).count,
      identifiers: Identification.joins(:observation).
        where("identifications.created_at BETWEEN ? AND ?", at_time - 1.day, at_time).
        where("identifications.user_id != observations.user_id").
        count("DISTINCT identifications.user_id"),
      recent_7_obs: User.
        where("created_at BETWEEN ? AND ?", at_time - 7.days, at_time).
        where("observations_count >= 7").
        count,
      recent_0_obs: User.
        where("created_at BETWEEN ? AND ?", at_time - 7.days, at_time).
        where("observations_count = 0").
        count
    }
  end

  def self.projects_stats(at_time = Time.now)
    at_time = at_time.utc
    { count: Project.where("created_at <= ?", at_time).count,
      last_7_days: Project.where("created_at BETWEEN ? AND ?", at_time - 7.days, at_time).count,
      today: Project.where("created_at BETWEEN ? AND ?", at_time - 1.day, at_time).count
    }
  end

  def self.taxa_stats(at_time = Time.now)
    at_time = at_time.utc
    { species_counts: Taxon.of_rank_equiv_or_lower(10).joins(:observations).
        where("observations.created_at <= ?", at_time).
        count(:id, distinct: true),
      species_counts_by_site: Hash[ Taxon.joins(observations: :site).
        where("observations.created_at <= ?", at_time).
        select("sites.name, count(distinct taxa.id) as count").
        of_rank_equiv_or_lower(10).
        group("sites.id").
        order("count(distinct taxa.id) desc").
        collect{ |a|
          [ a["name"], a["count"].to_i ]
        }
      ],
      count_by_rank: Hash[ Taxon.joins(:observations).
        where("observations.created_at <= ?", at_time).
        where("taxa.rank_level > 0").
        select("taxa.rank_level, count(distinct observations.id) as count").
        group("taxa.rank_level").
        order("count(distinct observations.id) desc").
        collect{ |a| [
          Taxon::RANK_LEVELS.select{ |k,v| v == a["rank_level"] }.first.try(:first) || "other",
          a["count"].to_i
        ]}
      ]
    }
  end

  def self.identifier_stats(at_time = Time.now)
    at_time = at_time.utc
    sql = <<-SQL
    SELECT 
      AVG(ttid)::numeric AS avg_ttid,
      MEDIAN(ttid)::numeric AS med_ttid,
      MIN(ttid)::numeric AS min_ttid,
      MAX(ttid)::numeric AS max_ttid,
      AVG(ttcid)::numeric AS avg_ttcid,
      MEDIAN(ttcid)::numeric AS med_ttcid,
      MIN(ttcid)::numeric AS min_ttcid,
      MAX(ttcid)::numeric AS max_ttcid,
      count(first_identification_id) / GREATEST(count(*),1)::float AS percent_id,
      count(community_taxon_id) / GREATEST(count(*),1)::float AS percent_cid,
      count(CASE WHEN community_taxon_rank_level <= 20 THEN 1 ELSE NULL END) / GREATEST(count(*),1)::float AS percent_cid_to_genus
    FROM (
      SELECT
        o.id,
        o.created_at,
        count(i.id) AS identifications_count,
        o.community_taxon_id,
        MIN(t.rank_level) AS community_taxon_rank_level,
        MIN(i.id) AS first_identification_id,
        (EXTRACT(EPOCH FROM MIN(i.created_at)) - EXTRACT(EPOCH FROM o.created_at)) AS ttid,
        (EXTRACT(EPOCH FROM MIN(ci.created_at)) - EXTRACT(EPOCH FROM o.created_at)) AS ttcid
      FROM observations o
        LEFT OUTER JOIN (
          SELECT identifications.* 
          FROM identifications JOIN observations ON identifications.observation_id = observations.id
          WHERE 
            identifications.user_id != observations.user_id AND
            identifications.created_at BETWEEN '#{(at_time - 1.week).to_s(:db)}' AND '#{at_time.to_s(:db)}'
        ) i ON i.observation_id = o.id
        LEFT OUTER JOIN (
          SELECT identifications.* 
          FROM identifications JOIN observations ON identifications.observation_id = observations.id
          WHERE 
            identifications.user_id != observations.user_id AND
            identifications.taxon_id = observations.community_taxon_id AND
            identifications.created_at BETWEEN '#{(at_time - 1.week).to_s(:db)}' AND '#{at_time.to_s(:db)}'
        ) ci ON ci.observation_id = o.id
        LEFT OUTER JOIN taxa t ON t.id = o.community_taxon_id
      WHERE
        o.observation_photos_count > 0
      GROUP BY o.id
    ) AS obs_id_stats
    WHERE
      obs_id_stats.created_at BETWEEN '#{(at_time - 1.week).to_s(:db)}' AND '#{at_time.to_s(:db)}'
    SQL
    Site.connection.execute(sql)[0].inject({}) do |memo,pair|
      memo[pair[0]] = pair[1].to_numeric
      memo
    end
  end

  def self.platforms_stats(at_time = Time.now)
    at_time = at_time.utc
    date_filter = { range: { created_at: { gte: at_time - 1.day, lt: at_time } } }
    iphone_app_id = OauthApplication.inaturalist_iphone_app.try(:id) || -1
    android_app_id = OauthApplication.inaturalist_android_app.try(:id) || -1
    { web: Observation.elastic_search({
        filters: [
          date_filter,
          { bool: { must_not: { exists: { field: "oauth_application_id" } } } }
        ]}).total_entries,
      iphone: Observation.elastic_search({
        filters: [
          date_filter,
          { term: { oauth_application_id: iphone_app_id } }
        ]}).total_entries,
      android: Observation.elastic_search({
        filters: [
          date_filter,
          { term: { oauth_application_id: android_app_id } }
        ]}).total_entries,
      other: Observation.elastic_search({
        filters: [
          date_filter,
          {
            bool: {
              must: { exists: { field: "oauth_application_id" } },
              must_not: { terms: { oauth_application_id: [
                iphone_app_id,
                android_app_id
              ] } }
            }
          }
        ]}).total_entries
    }
  end

  def self.platforms_cumulative_stats(at_time = Time.now)
    at_time = at_time.utc
    date_filter = { range: { created_at: { lte: at_time } } }
    iphone_app_id = OauthApplication.inaturalist_iphone_app.try(:id) || -1
    android_app_id = OauthApplication.inaturalist_android_app.try(:id) || -1
    { web: Observation.elastic_search({
        filters: [
          date_filter,
          { bool: { must_not: { exists: { field: "oauth_application_id" } } } }
        ]}).total_entries,
      iphone: Observation.elastic_search({
        filters: [
          date_filter,
          { term: { oauth_application_id: iphone_app_id } }
        ]}).total_entries,
      android: Observation.elastic_search({
        filters: [
          date_filter,
          { term: { oauth_application_id: android_app_id } }
        ]}).total_entries,
      other: Observation.elastic_search({
        filters: [
          date_filter,
          {
            bool: {
              must: { exists: { field: "oauth_application_id" } },
              must_not: { terms: { oauth_application_id: [
                iphone_app_id,
                android_app_id
              ] } }
            }
          }
        ]}).total_entries
    }
  end

end
