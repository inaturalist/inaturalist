class SiteStatistic < ActiveRecord::Base

  STAT_TYPES = [ :observations, :users, :projects,
    :taxa, :identifications ]

  def self.generate_stats_for_day(at_time = Time.now)
    at_time = at_time.utc.end_of_day
    return if stats_generated_for_day?(at_time)
    SiteStatistic.create({
      data: Hash[
        STAT_TYPES.map{ |st| [ st, send("#{ st }_stats", at_time) ] }
      ].to_json,
      created_at: at_time.beginning_of_day
    })
  end

  def self.generate_stats_for_date_range(start_time, end_time = Time.now)
    start_time = start_time.utc.end_of_day
    end_time = end_time.utc.end_of_day
    until end_time < start_time
      generate_stats_for_day(end_time)
      end_time -= 1.day
    end
  end

  def self.stats_generated_for_day?(at_time = Time.now)
    SiteStatistic.where("DATE(created_at) = DATE(?)", at_time.utc).exists?
  end

  private

  def self.observations_stats(at_time = Time.now)
    at_time = at_time.utc
    { count: Observation.where("created_at <= ?", at_time).count,
      research_grade: Observation.where("created_at <= ?", at_time).
        has_quality_grade(Observation::RESEARCH_GRADE).count,
      last_7_days: Observation.where("created_at BETWEEN ? AND ?", at_time - 7.days, at_time).count
    }
  end

  def self.identifications_stats(at_time = Time.now)
    at_time = at_time.utc
    { count: Identification.where("created_at <= ?", at_time).count,
      last_7_days: Identification.where("created_at BETWEEN ? AND ?", at_time - 7.days, at_time).count
    }
  end

  def self.users_stats(at_time = Time.now)
    at_time = at_time.utc
    { count: User.where("created_at <= ?", at_time).count,
      curators: User.where("created_at <= ?", at_time).curators.count,
      admins: User.where("created_at <= ?", at_time).admins.count,
      active: User.active_ids(at_time).count,
      last_7_days: User.where("created_at BETWEEN ? AND ?", at_time - 7.days, at_time).count }
  end

  def self.projects_stats(at_time = Time.now)
    at_time = at_time.utc
    { count: Project.where("created_at <= ?", at_time).count,
      last_7_days: Project.where("created_at BETWEEN ? AND ?", at_time - 7.days, at_time).count }
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
        collect{ |a|
          [ Taxon::RANK_LEVELS.select{ |k,v| v == a["rank_level"] }.first.first, a["count"].to_i ]
        }
      ]
    }
  end

end
