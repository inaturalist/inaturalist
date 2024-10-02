# frozen_string_literal: true

require "rubygems"
require "optimist"
require "observation_geo_score_updater"

OPTS = Optimist.options do
  banner <<-BANNER

  Update observation geo scores in the database and elasticsearch. Scores can be updated
  for all observations, such as when a new geo model is released, or scores can be updated
  based on observation updated_at values, to keep scores updated as observations change
  over time.

  Usage:

    rails runner tools/observation_geo_score_updater.rb -v VISION_API_URL -t TAXONOMY_PATH -s SYNONYMS_PATH -m UPDATED_MINUTES_AGO

  where [options] are:
  BANNER
  opt :vision_api_url, "URL to the vision API.", type: :string, short: "-v"
  opt :updated_minutes_ago, "Target observations updated since this many minutes ago.", type: :integer, short: "-m"
  opt :update_all, "Target all observations.", type: :boolean, short: "-a"
  opt :min_id, "Minimum ID to process.", type: :integer, short: "-f"
  opt :max_id, "Maximum ID to process.", type: :integer, short: "-t"
  opt :not_expected_nearby, "Filter to obeservations already indexed with a geo_score less than 1.",
    type: :boolean, short: "-n"
end

unless OPTS.vision_api_url
  puts "You must specify a vision API URL"
  exit( 0 )
end

unless OPTS.updated_minutes_ago || OPTS.update_all || ( OPTS.min_id && OPTS.max_id )
  puts "You must specify `updated_minutes_ago`, `update_all`, or `min_id` and `max_id` options"
  exit( 0 )
end

observation_geo_score_updater = ObservationGeoScoreUpdater.new(
  OPTS.vision_api_url
)

if OPTS.updated_minutes_ago
  observation_geo_score_updater.index_via_elasticsearch_observations_updated_since(
    OPTS.updated_minutes_ago.minutes.ago
  )
elsif OPTS.min_id && OPTS.max_id
  observation_geo_score_updater.index_all_via_elasticsearch(
    min_id: OPTS.min_id,
    max_id: OPTS.max_id,
    not_expected_nearby: OPTS.not_expected_nearby
  )
else
  observation_geo_score_updater.index_all_via_elasticsearch(
    not_expected_nearby: OPTS.not_expected_nearby
  )
end
