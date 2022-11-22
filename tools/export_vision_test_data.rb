require "rubygems"
require "optimist"

OPTS = Optimist::options do
    banner <<-EOS

Export observations to test with cv_model_test.js in the iNaturalistAPI repo

Usage:

  rails runner tools/export_vision_scores.rb
  rails runner tools/export_vision_scores.rb --sample-size 1000 --query "taxon_id=123&place_id=456"

where [options] are:
EOS
  opt :debug, "Print debug statements", type: :boolean, short: "-d"
  opt :file, "Where to write output", type: :string, short: "-f", default: "test-obs.csv"
  opt :per_page, "Number of obs to fetch per page", type: :int, short: "-p", default: 1000
  opt :sample_size, "Number of observations to sample", type: :int, short: "-s", default: 50000
  opt :query, "Observation search query to filter obs. Note that with_photos and order_by will be overridden",
    type: :string, short: "-q"
end


last_id = Observation.maximum(:id)

# Extract elastic filters from the query and override to add filters we need,
# like requiring photos and taxa
query_params = Rack::Utils.parse_nested_query( OPTS.query ).symbolize_keys
query_params[:with_photos] = true
query_params[:identified] = true
query_params.delete(:order_by)
query_params.delete(:order)
elastic_query = Observation.params_to_elastic_query( query_params )
filters = elastic_query[:filters]
inverse_filters = elastic_query[:inverse_filters]

source = [ "id", "taxon.id", "taxon.ancestry", "taxon.iconic_taxon_id", "observed_on_details.date", "location", "photos" ]

csv_file = File.open( OPTS.file, "w" )
csv_file.sync = true
count_written = 0
write_limit = OPTS.sample_size
keep_going = true
ids_written = { }
num_blank_iterations = 0
logger = Logger.new( STDOUT )

csv_file.write( "observation_id,observed_on,iconic_taxon_id,taxon_id,taxon_ancestry,lat,lng,photo_url\n" )

begin
  while keep_going do
    iteration_filters = filters.clone
    iteration_inverse_filters = inverse_filters.clone
    response = Observation.elastic_search(
      size: OPTS.per_page,
      filters: iteration_filters,
      inverse_filters: iteration_inverse_filters,
      source: source,
      sort: "random"
    )
    if response.blank? || response.total_entries.blank? || response.total_entries == 0
      keep_going = false
      break
    end
    result_obs = response.results.results
    result_ids = result_obs.map(&:id) - ids_written.keys
    # pp result_ids
    logger.info "#{result_ids.size} new obs"
    if result_ids.blank?
      num_blank_iterations += 1
      if num_blank_iterations > 2
        keep_going = false
        logger.error "Three consecutive queries with no results, bailing"
      end
      next
    else
      num_blank_iterations = 0
    end
    db_observations = Observation.where(id: result_ids).includes(observation_photos: :photo)
    db_obs_by_id = { }
    db_observations.each do |db_obs|
      db_obs_by_id[db_obs.id] = db_obs
    end
    result_obs.each do |obs|
      db_obs = db_obs_by_id[obs.id.to_i]
      next unless db_obs
      lat,lng = obs.location.to_s.split( "," )
      best_photo_url = db_obs.observation_photos.sort_by(&:position).first.photo.medium_url rescue nil
      next unless best_photo_url
      best_photo_url = best_photo_url.sub(/\?.*/, "")
      best_photo_url = best_photo_url.sub( /http:\/\//, "https://" )
      best_photo_url = best_photo_url.sub( /square/, "medium" )
      next unless best_photo_url =~ /\.jpe?g$/
      count_written += 1
      columns = [
        obs.id,
        obs.observed_on_details.date,
        obs.taxon.iconic_taxon_id,
        obs.taxon.id,
        obs.taxon.ancestry.tr( ",", "/" ),
        lat,
        lng,
        best_photo_url
      ]
      csv_file.write( "#{columns.join( ',' )}\n" )
      ids_written[obs.id] = true
      if count_written > write_limit
        keep_going = false
        break
      end
    end
  end
rescue IOError => e
ensure
  unless csv_file.nil?
    csv_file.close
    logger.info "Wrote #{ids_written.keys.size} obs to #{csv_file.path}"
  end
end
