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
end

unless OPTS.vision_api_url
  puts "You must specify a vision API URL"
  exit( 0 )
end

unless OPTS.updated_minutes_ago || OPTS.update_all
  puts "You must specify either a `updated_minutes_ago` or `update_all` option"
  exit( 0 )
end

observation_geo_score_updater = ObservationGeoScoreUpdater.new(
  OPTS.vision_api_url
)

if OPTS.updated_minutes_ago
  observation_geo_score_updater.index_via_elasticsearch_observations_updated_since(
    OPTS.updated_minutes_ago.minutes.ago
  )
else
  observation_geo_score_updater.index_all_via_elasticsearch
end
