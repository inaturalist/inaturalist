#!/usr/bin/env ruby

days_to_generate = 365
target_date = Time.now.utc.end_of_day

days_to_generate.times do
  at_time = target_date
  puts "Updating unknown-after-30-days for #{at_time}"
  stat = SiteStatistic.where( "DATE(created_at) = DATE(?)", at_time.utc ).order( "created_at desc" ).first
  unless stat
    puts "  No SiteStatistic for #{at_time.to_date}, skipping"
    target_date -= 1.day
    next
  end

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

  observations_with_ids = Identification.elastic_search(
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
          "observation.created_at": {
            lte: at_time - 30.days
          }
        }
      }
    ],
    aggs: {
      distinct_observations: {
        cardinality: {
          field: "observation.id",
          precision_threshold: 40_000
        }
      }
    }
  ).aggregations.distinct_observations.value

  created_30_days_not_identified = created_30_days - observations_with_ids
  created_30_days_not_identified = 0 if created_30_days_not_identified.negative?

  puts "#{created_30_days_not_identified} unkwown / #{created_30_days} total"

  data = stat.data || {}
  obs_data = data["observations"] || {}
  obs_data["created_30_days"] = created_30_days
  obs_data["created_30_days_not_identified"] = created_30_days_not_identified
  data["observations"] = obs_data
  stat.update_columns( data: data )

  target_date -= 1.day
end
