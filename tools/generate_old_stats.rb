#!/usr/bin/env ruby

days_to_generate = 365
target_date = Time.now.utc.end_of_day

days_to_generate.times do
  at_time = target_date
  puts "Updating stats for #{at_time}"
  stat = SiteStatistic.where( "DATE(created_at) = DATE(?)", at_time.utc ).order( "created_at desc" ).first
  unless stat
    puts "  No SiteStatistic for #{at_time.to_date}, skipping"
    target_date -= 1.day
    next
  end

  # Observations:
  created_30_days = Observation.elastic_search(
    size: 0,
    track_total_hits: true,
    filters: [
      {
        range: {
          created_at: {
            lte: at_time - 30.days
          }
        }
      }
    ]
  ).total_entries

  created_30_days_not_identified = Observation.elastic_search(
    size: 0,
    track_total_hits: true,
    filters: [
      {
        range: {
          created_at: {
            lte: at_time - 30.days
          }
        }
      },
      {
        bool: {
          must_not: {
            exists: {
              field: "taxon"
            }
          }
        }
      }
    ]
  ).total_entries

  today_identified_by_others = Identification.elastic_search(
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
      {
        term: { own_observation: false }
      },
      {
        bool: {
          must_not: {
            exists: {
              field: "taxon_change.id"
            }
          }
        }
      }
    ],
    aggs: {
      distinct_observations: {
        cardinality: {
          field: "observation.id"
        }
      }
    }
  ).aggregations.distinct_observations.value

  today_identified_by_others_by_iconic_taxon = {}
  Identification.elastic_search(
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
      {
        term: { own_observation: false }
      },
      {
        bool: {
          must_not: {
            exists: {
              field: "taxon_change.id"
            }
          }
        }
      }
    ],
    aggs: {
      iconic_taxa: {
        terms: {
          field: "taxon.iconic_taxon_id",
          size: 50
        },
        aggs: {
          distinct_observations: {
            cardinality: {
              field: "observation.id"
            }
          }
        }
      }
    }
  ).aggregations.iconic_taxa.buckets.each do | bucket |
    today_identified_by_others_by_iconic_taxon[bucket["key"]] = bucket["distinct_observations"]["value"]
  end

  # Identifications (copied from SiteStatistic.identifications_stats)
  count_for_others = Identification.elastic_search(
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
        term: { own_observation: false }
      },
      {
        bool: {
          must_not: {
            exists: {
              field: "taxon_change.id"
            }
          }
        }
      }
    ]
  ).total_entries

  today_for_others = Identification.elastic_search(
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
      {
        term: { own_observation: false }
      },
      {
        bool: {
          must_not: {
            exists: {
              field: "taxon_change.id"
            }
          }
        }
      }
    ]
  ).total_entries

  last_7_days_for_others = Identification.elastic_search(
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
        term: { own_observation: false }
      },
      {
        bool: {
          must_not: {
            exists: {
              field: "taxon_change.id"
            }
          }
        }
      }
    ]
  ).total_entries

  data = stat.data || {}

  obs_data = data["observations"] || {}
  obs_data["created_30_days"] = created_30_days
  obs_data["created_30_days_not_identified"] = created_30_days_not_identified
  obs_data["today_identified_by_others"] = today_identified_by_others
  obs_data["today_identified_by_others_by_iconic_taxon"] = today_identified_by_others_by_iconic_taxon
  data["observations"] = obs_data

  ident_data = data["identifications"] || {}
  ident_data["count_for_others"] = count_for_others
  ident_data["today_for_others"] = today_for_others
  ident_data["last_7_days_for_others"] = last_7_days_for_others
  data["identifications"] = ident_data

  stat.update_columns( data: data )

  target_date -= 1.day
end
