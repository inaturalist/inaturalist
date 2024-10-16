# frozen_string_literal: true

class ObservationGeoScoreUpdater
  attr_reader :start_time,
    :vision_api_url

  GEO_SCORE_MAPPING = "geo_score"

  def initialize( vision_api_url )
    @start_time = Time.now.to_i
    @vision_api_url = vision_api_url
    validate_parameters
  end

  def validate_parameters
    return unless @vision_api_url.blank?

    raise "ERROR: vision_api_url is not defined"
  end

  def index_all_via_database
    maximum_id = Observation.maximum( :id )
    chunk_start_id = 1
    search_chunk_size = 5_000
    start_time = Time.now
    while chunk_start_id <= maximum_id
      puts "Loop starting at #{chunk_start_id}; time: #{( Time.now - start_time ).round( 2 )}"
      chunk_id_below = chunk_start_id + search_chunk_size
      batch = Observation.where( "id >= ?", chunk_start_id ).
        where( "id < ?", chunk_id_below ).
        select( :id, :taxon_id, :latitude, :longitude, :private_latitude, :private_longitude ).to_a

      Observation.preload_associations( batch, :taxon )
      observations_to_score = batch.map do | obs |
        next unless obs.taxon && (
          ( obs.latitude && obs.longitude ) ||
          ( obs.private_latitude && obs.private_longitude )
        )

        {
          id: obs.id,
          taxon_id: obs.taxon.id,
          lat: obs.coordinates_obscured? ? obs.private_latitude : obs.latitude,
          lng: obs.coordinates_obscured? ? obs.private_longitude : obs.longitude
        }
      end.compact

      index_observation_range( observations_to_score, chunk_start_id, chunk_id_below )
      chunk_start_id += search_chunk_size
    end
  end

  def index_all_via_elasticsearch( min_id: nil, max_id: nil, not_expected_nearby: nil )
    maximum_id = max_id || Observation.maximum( :id )
    chunk_start_id = min_id || 1
    search_chunk_size = 5_000
    start_time = Time.now
    while chunk_start_id <= maximum_id
      puts "Loop starting at #{chunk_start_id}; time: #{( Time.now - start_time ).round( 2 )}"
      chunk_id_below = chunk_start_id + search_chunk_size
      if chunk_id_below > maximum_id
        chunk_id_below = maximum_id + 1
      end

      query_filters = [
        { range: { id: { gte: chunk_start_id } } },
        { range: { id: { lt: chunk_id_below } } }
      ]
      if not_expected_nearby
        query_filters << {
          range: { geo_score: { lt: 1.0 } }
        }
      end
      elastic_response = Observation.elastic_search(
        sort: { id: :asc },
        size: search_chunk_size,
        filters: query_filters,
        source: ["id", "taxon.id", "location", "private_location"]
      )

      if not_expected_nearby
        # when using the `not_expected_nearby` option, we only want to udpate scores from results,
        # not all scores for all observations from the entire ID range
        index_observations_from_elastic_response( elastic_response )
      else
        index_observation_range(
          map_elastic_response_to_observations_to_score( elastic_response ),
          chunk_start_id,
          chunk_id_below
        )
      end
      chunk_start_id += search_chunk_size
    end
  end

  def index_via_elasticsearch_observations_updated_since( updated_since )
    search_after = nil
    results_remaining = true
    start_time = Time.now
    while results_remaining
      elastic_response = Observation.elastic_search(
        sort: { id: :asc },
        search_after: search_after,
        size: 5_000,
        filters: [
          { range: { updated_at: { gte: updated_since.strftime( "%FT%T%:z" ) } } },
          { bool: {
            must_not: [{
              exists: {
                field: GEO_SCORE_MAPPING
              }
            }]
          } }
        ],
        source: ["id", "taxon.id", "location", "private_location"]
      )
      if elastic_response.response.hits.hits.empty?
        results_remaining = false
        break
      end

      puts "Loop starting at #{search_after&.first || 1}; time: #{( Time.now - start_time ).round( 2 )}"
      search_after = [elastic_response.response.hits.hits.last._source.id]
      index_observations_from_elastic_response( elastic_response )
    end
  end

  def index_observations_from_elastic_response( elastic_response )
    observations_to_score = map_elastic_response_to_observations_to_score( elastic_response )
    geo_scores_response = RestClient.post(
      "#{@vision_api_url}/geo_scores_for_taxa", {
        observations: observations_to_score
      }.to_json, content_type: :json, accept: :json
    )
    geo_scores = JSON.parse( geo_scores_response )
    index_batch( geo_scores, delete_existing_scores: true )
  end

  def map_elastic_response_to_observations_to_score( elastic_response )
    elastic_response.response.hits.hits.map do | h |
      next unless (
        h._source.private_location || h._source.location
      ) && h._source&.taxon&.id

      latlng = ( h._source.private_location || h._source.location ).split( "," )
      {
        id: h._source.id,
        taxon_id: h._source.taxon.id,
        lat: latlng[0],
        lng: latlng[1]
      }
    end.compact
  end

  def index_observation_range( observations_to_score, chunk_start_id, chunk_id_below )
    geo_scores_response = RestClient.post(
      "#{@vision_api_url}/geo_scores_for_taxa", {
        observations: observations_to_score
      }.to_json, content_type: :json, accept: :json
    )
    geo_scores = JSON.parse( geo_scores_response )
    ObservationGeoScore.where( "observation_id >= ?", chunk_start_id ).
      where( "observation_id < ?", chunk_id_below ).delete_all
    index_batch( geo_scores )
  end

  def index_batch( geo_scores, options = {} )
    return if geo_scores.blank?

    Observation.transaction do
      if options[:delete_existing_scores]
        ObservationGeoScore.where( observation_id: geo_scores.keys ).delete_all
      end
      geo_scores_to_insert = geo_scores.compact.map do | k, score |
        { observation_id: k, geo_score: score }
      end
      unless geo_scores_to_insert.empty?
        ObservationGeoScore.insert_all( geo_scores_to_insert )
      end
    end

    try_and_try_again(
      [
        Elastic::Transport::Transport::Errors::ServiceUnavailable,
        Elastic::Transport::Transport::Errors::TooManyRequests
      ], sleep: 1, tries: 10
    ) do
      begin
        Observation.__elasticsearch__.client.bulk( {
          index: Observation.index_name,
          body: geo_scores.map do | k, score |
            { update: { _id: k, data: { doc: { GEO_SCORE_MAPPING => score } } } }
          end,
          refresh: false
        } )
      rescue Elastic::Transport::Transport::Errors::BadRequest => e
        Logstasher.write_exception( e )
        Rails.logger.error "[Error] ObservationGeoScoreUpdater.index_batch failed: #{e}"
        Rails.logger.error "Backtrace:\n#{e.backtrace[0..30].join( "\n" )}\n..."
      end
    end
  end

  def inspect
    "#<ObservationGeoScoreUpdater @vision_api_url=\"#{@vision_api_url}, ...\">"
  end
end
