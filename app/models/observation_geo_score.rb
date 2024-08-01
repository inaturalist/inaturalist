# frozen_string_literal: true

class ObservationGeoScore < ApplicationRecord
  belongs_to :observation
  validates_uniqueness_of :observation_id

  def self.thething
    return unless CONFIG.vision_api_url

    maximum_id = Observation.maximum( :id )
    chunk_start_id = 1
    search_chunk_size = 5_000
    start_time = Time.now
    while chunk_start_id <= maximum_id
      puts "Loop starting at #{chunk_start_id}; time: #{( Time.now - start_time ).round( 2 )}"
      chunk_id_below = chunk_start_id + search_chunk_size
      batch = Observation.where( "id >= ?", chunk_start_id ).
        where( "id < ?", chunk_id_below ).to_a

      Observation.preload_associations( batch, :taxon )
      geo_scores_response = RestClient.post(
        "#{CONFIG.vision_api_url}/geo_scores_for_taxa", {
          observations: batch.filter do | observation |
            observation.taxon && observation.latitude && observation.longitude
          end.map do | observation |
            {
              id: observation.id,
              taxon_id: observation.taxon.id,
              lat: observation.latitude,
              lng: observation.longitude
            }
          end
        }.to_json, content_type: :json, accept: :json
      )
      geo_scores = JSON.parse( geo_scores_response )

      Observation.transaction do
        ObservationGeoScore.where( "observation_id >= ?", chunk_start_id ).
          where( "observation_id < ?", chunk_id_below ).delete_all
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
              { update: { _id: k, data: { doc: { geo_score_test1: score } } } }
            end,
            refresh: false
          } )
        rescue Elastic::Transport::Transport::Errors::BadRequest => e
          Logstasher.write_exception( e )
          Rails.logger.error "[Error] elastic_index! failed: #{e}"
          Rails.logger.error "Backtrace:\n#{e.backtrace[0..30].join( "\n" )}\n..."
        end
      end
      chunk_start_id += search_chunk_size
    end
  end
end
