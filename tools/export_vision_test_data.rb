last_id = Observation.maximum(:id)

filters = [
  { terms: { quality_grade: ["casual"] } },
  { term: { identifications_most_agree: true } },
  { exists: { field: "photos_count" } },
  { exists: { field: "location" } },
  { exists: { field: "observed_on_details.date" } },
  { range: { created_at: { gte: "2019-10-01" } } },
  { term: { "taxon.rank_level": Taxon::RANK_LEVELS["species"] } },
  # { terms: { place_ids: [97389] } } # South America
  # { terms: { place_ids: [57241] } } # Southeast Asia
  # { terms: { place_ids: [97391] } } # Europe
  # { terms: { place_ids: [7161] } } # Russia
  # { terms: { place_ids: [14] } } # California
  # { terms: { place_ids: [118147,6803,97393] } } # Oceania
]
source = [ "id", "taxon.id", "taxon.ancestry", "taxon.iconic_taxon_id", "observed_on_details.date", "location", "photos" ]

log_file = File.open( "test-obs.csv", "w" )
log_file.sync = true
count_written = 0
write_limit = 50000
keep_going = true
ids_written = { }

log_file.write( "observation_id,observed_on,iconic_taxon_id,taxon_id,taxon_ancestry,lat,lng,photo_url\n" )

begin
  while keep_going do
    iteration_filters = filters.clone
    response = Observation.elastic_search( size: 1000, filters: iteration_filters,
      source: source, sort: "random" )
    if response.blank? || response.total_entries.blank? || response.total_entries == 0
      keep_going = false
      break
    end
    result_obs = response.results.results
    result_ids = result_obs.map(&:id) - ids_written.keys
    pp result_ids
    db_observations = Observation.where(id: result_ids).includes(observation_photos: :photo)
    db_obs_by_id = { }
    db_observations.each do |db_obs|
      db_obs_by_id[db_obs.id] = db_obs
    end
    result_obs.each do |obs|
      db_obs = db_obs_by_id[obs.id.to_i]
      next unless db_obs
      lat,lng = obs.location.split( "," )
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
      log_file.write( "#{columns.join( ',' )}\n" )
      ids_written[obs.id] = true
      if count_written > write_limit
        keep_going = false
        break
      end
    end
  end
rescue IOError => e
ensure
  log_file.close unless log_file.nil?
end
