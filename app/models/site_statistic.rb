class SiteStatistic < ApplicationRecord

  STAT_TYPES = [ :observations, :users, :projects,
    :taxa, :identifications, :identifier, :platforms, :platforms_cumulative ]

  def self.generate_stats_for_day(at_time = Time.now, options = {})
    at_time = at_time.utc.end_of_day
    if options[:force]
      SiteStatistic.where("DATE(created_at) = DATE(?)", at_time.utc).delete_all
    elsif stats_generated_for_day?(at_time)
      return
    end
    sleep 1
    SiteStatistic.create!(
      data: Hash[
        STAT_TYPES.map{ |st| [ st, send("#{ st }_stats", at_time) ] }
      ],
      created_at: at_time.beginning_of_day
    )
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
    count = Observation.elastic_search(
      size: 0,
      track_total_hits: true,
      filters: [
        range: {
          created_at: {
            lte: at_time
          }
        }
      ]
    ).total_entries
    research_grade = Observation.elastic_search(
      size: 0,
      track_total_hits: true,
      filters: [
        {
          range: {
            created_at: {
              lte: at_time
            }
          }
        },
        {
          terms: {
            quality_grade: [Observation::RESEARCH_GRADE]
          }
        }
      ]
    ).total_entries
    last_7_days = Observation.elastic_search(
      size: 0,
      track_total_hits: true,
      filters: [
        range: {
          created_at: {
            gte: at_time - 7.days,
            lte: at_time
          }
        }
      ]
    ).total_entries
    today = Observation.elastic_search(
      size: 0,
      track_total_hits: true,
      filters: [
        range: {
          created_at: {
            gte: at_time - 1.days,
            lte: at_time
          }
        }
      ]
    ).total_entries
    identified = Observation.elastic_search(
      size: 0,
      track_total_hits: true,
      filters: [
        {
          range: {
            created_at: {
              gte: at_time - 7.days,
              lte: at_time
            }
          }
        },
        {
          exists: { field: "taxon" }
        }
      ]
    ).total_entries
    community_identified = Observation.elastic_search(
      size: 0,
      track_total_hits: true,
      filters: [
        {
          range: {
            created_at: {
              gte: at_time - 7.days,
              lte: at_time
            }
          }
        },
        {
          exists: { field: "community_taxon_id" }
        }
      ]
    ).total_entries
    # community_identified_to_genus_taxon
    # 1. get all community taxon ids / count from ES observations
    # 2. filter this taxon ids list to rank<=genus using Postgres 
    #    (since we don't have taxon rank info in ES)
    # 3. for each community taxon id being <=genus, sum the count
    #    from previous ES observations query
    community_identified_to_genus = 0
    community_identified_to_genus_taxon_ids = Observation.elastic_search(
      size: 0,
      track_total_hits: true,
      filters: [
        {
          range: {
            created_at: {
              gte: at_time - 7.days,
              lte: at_time
            }
          }
        },
        {
          exists: { field: "community_taxon_id" }
        }        
      ],
      aggregate: {
        community_taxon_id: {
          terms: { field: "community_taxon_id", size: 10000000 }
        }
      }
    ).response.aggregations.community_taxon_id.
      buckets.map { |b| 
          [ b["key"], b["doc_count"] ]
        }.to_h
    community_identified_to_genus_taxon_ids.keys.each_slice(10000) do |batch_taxon_ids|
      batch_taxon_ids_filtered = Taxon.where("rank_level <= 20").
        where("id IN (?)", batch_taxon_ids).
        select("id").collect { |taxon_id| 
          community_identified_to_genus += community_identified_to_genus_taxon_ids[taxon_id.id] 
        }
    end
    {
      # count: Observation.where("created_at <= ?", at_time).count,
      count: count,
      # research_grade: Observation.where("created_at <= ?", at_time).
      #   has_quality_grade(Observation::RESEARCH_GRADE).count,
      research_grade: research_grade,
      # last_7_days: Observation.where("created_at BETWEEN ? AND ?", at_time - 7.days, at_time).count,
      last_7_days: last_7_days,
      # today: Observation.where("created_at BETWEEN ? AND ?", at_time - 1.day, at_time).count,
      today: today,
      # identified: Observation.where("taxon_id IS NOT NULL AND created_at BETWEEN ? AND ?", at_time - 7.days, at_time).count,
      identified: identified,
      # community_identified: Observation.where("community_taxon_id IS NOT NULL AND created_at BETWEEN ? AND ?", at_time - 7.days, at_time).count,
      community_identified: community_identified,
      community_identified_to_genus: community_identified_to_genus
    }
  end

  def self.identifications_stats(at_time = Time.now)
    at_time = at_time.utc
    count = Identification.elastic_search(
      size: 0,
      track_total_hits: true,
      filters: [
        range: {
          created_at: {
            lte: at_time
          }
        }
      ]
    ).total_entries
    last_7_days = Identification.elastic_search(
      size: 0,
      track_total_hits: true,
      filters: [
        range: {
          created_at: {
            gte: at_time - 7.days,
            lte: at_time
          }
        }
      ]
    ).total_entries
    today = Identification.elastic_search(
      size: 0,
      track_total_hits: true,
      filters: [
        range: {
          created_at: {
            gte: at_time - 1.days,
            lte: at_time
          }
        }
      ]
    ).total_entries
    {
      count: count,
      last_7_days: last_7_days,
      today: today
    }
  end

  def self.users_stats(at_time = Time.now)
    at_time = at_time.utc
    count = User.elastic_search(
      size: 0,
      track_total_hits: true,
      filters: [
        {
          range: {
            created_at: {
              lte: at_time
            }
          }
        },
        { term: { spam: false } }
      ]
    ).total_entries
    curators = User.elastic_search(
      size: 0,
      track_total_hits: true,
      filters: [
        {
          range: {
            created_at: {
              lte: at_time
            }
          }
        },
        { term: { spam: false } },
        { term: { roles: ["curator", "admin"] } }
      ]
    ).total_entries
    admins = User.elastic_search(
      size: 0,
      track_total_hits: true,
      filters: [
        {
          range: {
            created_at: {
              lte: at_time
            }
          }
        },
        { term: { spam: false } },
        { term: { roles: "admin" } }
      ]
    ).total_entries
    active_from_observations = Observation.elastic_search(
      size: 0,
      filters: [
        {
          range: {
            created_at: {
              gte: at_time - 30.days,
              lte: at_time
            }
          }
        }
      ],
      aggregate: {
        user_id: {
          terms: { field: "user.id", size: 10000000 }
        }
      }
    ).response.aggregations.user_id.
      buckets.map { |b| 
          b["key"]
        }
    active_from_identifications = Identification.elastic_search(
      size: 0,
      filters: [
        {
          range: {
            created_at: {
              gte: at_time - 30.days,
              lte: at_time
            }
          }
        }
      ],
      aggregate: {
        user_id: {
          terms: { field: "user.id", size: 10000000 }
        }
      }
    ).response.aggregations.user_id.
      buckets.map { |b| 
          b["key"]
        }
    active_from_comments = Comment.select("DISTINCT(user_id)").
      where(created_at: (at_time - 30.days)..at_time).
      collect{ |i| i.user_id }
    active_from_posts = Post.select("DISTINCT(user_id)").
      where(created_at: (at_time - 30.days)..at_time).
      collect{ |i| i.user_id }
    active = (active_from_observations + active_from_identifications + active_from_comments + active_from_posts).uniq.count
    last_7_days = User.elastic_search(
      size: 0,
      track_total_hits: true,
      filters: [
        {
          range: {
            created_at: {
              gte: at_time - 7.days,
              lte: at_time
            }
          }
        },
        { term: { spam: false } }
      ]
    ).total_entries
    today = User.elastic_search(
      size: 0,
      track_total_hits: true,
      filters: [
        {
          range: {
            created_at: {
              gte: at_time - 1.days,
              lte: at_time
            }
          }
        },
        { term: { spam: false } }
      ]
    ).total_entries
    identifiers = Identification.elastic_search(
      size: 0,
      track_total_hits: true,
      filters: [
        {
          range: {
            created_at: {
              gte: ( at_time - 1 .day ),
              lte: at_time
            }
          }
        },
        {
          term: { own_observation: false }
        }
      ],
      aggs: {
        distinct_users: {
          cardinality: {
            field: "user.id"
          }
        }
      }
    ).aggregations.distinct_users.value
    observers = Observation.elastic_search(
      size: 0,
      track_total_hits: true,
      filters: [
        { terms: { quality_grade: %w(research needs_id) } },
        {
          range: {
            created_at: {
              gte: ( at_time - 1 .day ),
              lte: at_time
            }
          }
        }
      ],
      aggs: {
        distinct_users: {
          cardinality: {
            field: "user.id"
          }
        }
      }
    ).aggregations.distinct_users.value    
    recent_7_obs = User.elastic_search(
      size: 0,
      track_total_hits: true,
      filters: [
        {
          range: {
            created_at: {
              gte: at_time - 7.days,
              lte: at_time
            }
          }
        },
        { term: { spam: false } },
        {
          range: {
            observations_count: {
              gte: 7
            }
          }
        }
      ]
    ).total_entries
    recent_0_obs = User.elastic_search(
      size: 0,
      track_total_hits: true,
      filters: [
        {
          range: {
            created_at: {
              gte: at_time - 7.days,
              lte: at_time
            }
          }
        },
        { term: { spam: false } },
        { term: { observations_count: 0 } }
      ]
    ).total_entries
    {
      count: count,
      curators: curators,
      admins: admins,
      active: active,
      last_7_days: last_7_days,
      today: today,
      identifiers: identifiers,
      observers: observers,
      recent_7_obs: recent_7_obs,
      recent_0_obs: recent_0_obs
    }
  end

  def self.projects_stats(at_time = Time.now)
    at_time = at_time.utc    
    count = Project.elastic_search(
      size: 0,
      track_total_hits: true,
      filters: [
        range: {
          created_at: {
            lte: at_time
          }
        }
      ]
    ).total_entries
    last_7_days = Project.elastic_search(
      size: 0,
      track_total_hits: true,
      filters: [
        range: {
          created_at: {
            gte: at_time - 7.days,
            lte: at_time
          }
        }
      ]
    ).total_entries
    today = Project.elastic_search(
      size: 0,
      track_total_hits: true,
      filters: [
        range: {
          created_at: {
            gte: at_time - 1.days,
            lte: at_time
          }
        }
      ]
    ).total_entries
    { count: count,
      last_7_days: last_7_days,
      today: today
    }
  end

  def self.taxa_stats(at_time = Time.now)
    at_time = at_time.utc
    species_counts = Observation.elastic_search(
      size: 0,
      track_total_hits: true,
      filters: [
        {
          range: {
            created_at: {
              lte: at_time
            }
          }
        },
        {
          range: {
            "taxon.rank_level": {
              lte: 10
            }
          }
        }
      ],
      aggregate: {
        species_counts: {
          cardinality: {
            field: "taxon.id"
          }
        }
      }
    ).response.aggregations.species_counts.value    
    sites = Site.select(:id, :name).map{ |s| 
        [ s.id, s.name ]
      }.to_h
    species_counts_by_site = {}
    Observation.elastic_search(
      size: 0,
      track_total_hits: true,
      filters: [
        {
          range: {
            created_at: {
              lte: at_time
            }
          }
        },
        {
          range: {
            "taxon.rank_level": {
              lte: 10
            }
          }
        }
      ],
      aggregate: {
        group_by_sites: {
          terms: {
            field: "site_id",
            size: 1000
          },
          aggs: {
            distinct_taxon_id: {
              cardinality: {
                field: "taxon.id"
              }
            }
          }
        }
      }
    ).response.aggregations.group_by_sites.
      buckets.map do |b| 
          if sites.key?(b["key"])
            site_name = sites[b["key"]]
            species_counts_by_site[site_name] = b["distinct_taxon_id"].value
          end
      end
    count_by_rank = {}
    Observation.elastic_search(
      size: 0,
      track_total_hits: true,
      filters: [
        {
          range: {
            created_at: {
              lte: at_time
            }
          }
        },
        {
          range: {
            "taxon.rank_level": {
              gt: 0
            }
          }
        }
      ],
      aggregate: {
        ranks: {
          terms: { field: "taxon.rank_level", size: 1000 }
        }
      }
    ).response.aggregations.ranks.
      buckets.map do |b| 
          rank_level_float = b["key"]
          rank_level = (rank_level_float.to_i == rank_level_float) ? rank_level_float.to_i : rank_level_float
          rank = Taxon::RANK_FOR_RANK_LEVEL[ rank_level ].presence || "other"
          count_by_rank[rank] = b["doc_count"]
        end
    { species_counts: species_counts,
      species_counts_by_site: species_counts_by_site,
      count_by_rank: count_by_rank
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
      memo[pair[0]] = pair[1].to_s.to_numeric
      memo
    end
  end

  def self.platforms_stats(at_time = Time.now)
    at_time = at_time.utc
    date_filter = { range: { created_at: { gte: at_time - 1.day, lt: at_time } } }
    iphone_app_id = OauthApplication.inaturalist_iphone_app.try(:id) || -1
    android_app_id = OauthApplication.inaturalist_android_app.try(:id) || -1
    {
      web: Observation.elastic_search(
        filters: [
          date_filter,
          { bool: { must_not: { exists: { field: "oauth_application_id" } } } }
        ],
        size: 0,
        track_total_hits: true
      ).total_entries,
      iphone: Observation.elastic_search(
        filters: [
          date_filter,
          { term: { "oauth_application_id.keyword": iphone_app_id } }
        ],
        size: 0,
        track_total_hits: true
      ).total_entries,
      android: Observation.elastic_search(
        filters: [
          date_filter,
          { term: { "oauth_application_id.keyword": android_app_id } }
        ],
        size: 0,
        track_total_hits: true
      ).total_entries,
      other: Observation.elastic_search(
        filters: [
          date_filter,
          {
            bool: {
              must: { exists: { field: "oauth_application_id" } },
              must_not: { terms: { "oauth_application_id.keyword": [
                iphone_app_id,
                android_app_id
              ] } }
            }
          }
        ],
        size: 0,
        track_total_hits: true
      ).total_entries
    }
  end

  def self.platforms_cumulative_stats(at_time = Time.now)
    at_time = at_time.utc
    date_filter = { range: { created_at: { lte: at_time } } }
    iphone_app_id = OauthApplication.inaturalist_iphone_app.try(:id) || -1
    android_app_id = OauthApplication.inaturalist_android_app.try(:id) || -1
    {
      web: Observation.elastic_search(
        filters: [
          date_filter,
          { bool: { must_not: { exists: { field: "oauth_application_id" } } } }
        ],
        size: 0,
        track_total_hits: true
      ).total_entries,
      iphone: Observation.elastic_search(
        filters: [
          date_filter,
          { term: { oauth_application_id: iphone_app_id } }
        ],
        size: 0,
        track_total_hits: true
      ).total_entries,
      android: Observation.elastic_search(
        filters: [
          date_filter,
          { term: { oauth_application_id: android_app_id } }
        ],
        size: 0,
        track_total_hits: true
      ).total_entries,
      other: Observation.elastic_search(
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
        ],
        size: 0,
        track_total_hits: true
      ).total_entries
    }
  end

end
