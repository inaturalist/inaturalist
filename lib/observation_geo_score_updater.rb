# frozen_string_literal: true

class ObservationGeoScoreUpdater
  attr_reader :start_time,
    :vision_api_url,
    :model_taxonomy_path,
    :model_synonyms_path,
    :model_taxa

  GEO_SCORE_MAPPING = "geo_score"

  def initialize( vision_api_url, model_taxonomy_path, model_synonyms_path )
    @start_time = Time.now.to_i
    @vision_api_url = vision_api_url
    @model_taxonomy_path = model_taxonomy_path
    @model_synonyms_path = model_synonyms_path
    validate_parameters
    load_taxonomy
    load_synonyms
  end

  def validate_parameters
    if @vision_api_url.blank?
      raise "ERROR: vision_api_url is not defined"
    end

    if @model_taxonomy_path.blank?
      raise "ERROR: model_taxonomy_path is not defined"
    end

    return unless @model_synonyms_path.blank?

    raise "ERROR: model_synonyms_path is not defined"
  end

  def load_taxonomy
    puts "[DEBUG] Loading taxonomy..."
    load_taxa_from_csv( @model_taxonomy_path, require_leaf_class_id: true )
  end

  def load_synonyms
    puts "[DEBUG] Loading synonyms..."
    load_taxa_from_csv( @model_synonyms_path )
  end

  def load_taxa_from_csv( path, options = {} )
    unless File.exist?( path )
      raise "ERROR: #{path} does not exist"
    end

    @model_taxa ||= {}
    CSV.foreach(
      path,
      headers: true,
      quote_char: nil
    ) do | row |
      next if options[:require_leaf_class_id] && row["leaf_class_id"].blank?

      @model_taxa[row["taxon_id"].to_i] = row
    end
  end

  def index_all_via_database
    return if @model_taxa.blank?

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
        next unless obs.taxon && @model_taxa[obs.taxon.id] && (
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

  def index_all_via_elasticsearch
    return if @model_taxa.blank?

    maximum_id = Observation.maximum( :id )
    chunk_start_id = 1
    search_chunk_size = 5_000
    start_time = Time.now
    while chunk_start_id <= maximum_id
      puts "Loop starting at #{chunk_start_id}; time: #{( Time.now - start_time ).round( 2 )}"
      chunk_id_below = chunk_start_id + search_chunk_size

      elastic_response = Observation.elastic_search(
        sort: { id: :asc },
        size: search_chunk_size,
        filters: [
          { range: { id: { gte: chunk_start_id } } },
          { range: { id: { lt: chunk_id_below } } }
        ],
        source: ["id", "taxon.id", "location", "private_location"]
      )

      index_observation_range(
        map_elastic_response_to_observations_to_score( elastic_response ),
        chunk_start_id,
        chunk_id_below
      )
      chunk_start_id += search_chunk_size
    end
  end

  def index_via_elasticsearch_observations_updated_since( updated_since )
    return if @model_taxa.blank?

    search_after = nil
    results_remaining = true
    while results_remaining
      elastic_response = Observation.elastic_search(
        sort: { id: :asc },
        search_after: search_after,
        size: 5_000,
        filters: [
          { range: { updated_at: { gte: updated_since.strftime( "%F" ) } } },
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

      search_after = [elastic_response.response.hits.hits.last._source.id]
      observations_to_score = map_elastic_response_to_observations_to_score( elastic_response )
      geo_scores_response = RestClient.post(
        "#{@vision_api_url}/geo_scores_for_taxa", {
          observations: observations_to_score
        }.to_json, content_type: :json, accept: :json
      )
      geo_scores = JSON.parse( geo_scores_response )
      index_batch( geo_scores, delete_existing_scores: true )
    end
  end

  def map_elastic_response_to_observations_to_score( elastic_response )
    elastic_response.response.hits.hits.map do | h |
      next unless (
        h._source.private_location || h._source.location
      ) && h._source&.taxon&.id && @model_taxa[h._source.taxon.id]

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
    "#<ObservationGeoScoreUpdater @model_taxonomy_path=\"#{@model_taxonomy_path}, ...\">"
  end
end
