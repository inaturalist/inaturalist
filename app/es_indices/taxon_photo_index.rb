# frozen_string_literal: true

class TaxonPhoto < ApplicationRecord
  include ActsAsElasticModel

  DEFAULT_ES_BATCH_SIZE = 100

  attr_accessor :calculated_embedding

  scope :load_for_index, lambda {
    includes(
      :taxon,
      photo: [
        :flags,
        :file_extension,
        :file_prefix,
        :moderator_actions
      ]
    )
  }

  settings index: {
    number_of_shards: Rails.env.production? ? 6 : 4,
    analysis: ElasticModel::ANALYSIS
  } do
    mappings( dynamic: false ) do
      indexes :ancestor_ids, type: "integer" do
        indexes :keyword, type: "keyword"
      end
      indexes :photo_file_updated_at, type: "date", index: false
      indexes :embedding,
        type: "dense_vector",
        index: true,
        dims: 2048,
        similarity: "cosine",
        index_options: {
          type: "int4_hnsw"
        }
      indexes :id, type: "integer" do
        indexes :keyword, type: "keyword"
      end
      indexes :photo_id, type: "integer" do
        indexes :keyword, type: "keyword"
      end
      indexes :taxon_id, type: "integer" do
        indexes :keyword, type: "keyword"
      end
    end
  end

  def as_indexed_json( options = {} )
    if options[:for_taxon]
      return {
        taxon_id: taxon_id,
        photo: photo.as_indexed_json(
          sizes: [:square, :small, :medium, :large, :original],
          native_page_url: true,
          native_photo_id: true,
          type: true
        )
      }
    end

    TaxonPhoto.prepare_batch_for_index( [self] ) unless calculated_embedding
    {
      id: id,
      taxon_id: taxon_id,
      photo_id: photo_id,
      photo_file_update_at: photo&.file_updated_at,
      ancestor_ids: ( taxon&.ancestry&.split( "/" )&.map( &:to_i ) || [] ) << id,
      embedding: calculated_embedding.blank? ? nil : calculated_embedding
    }
  end

  def self.prepare_batch_for_index( taxon_photos )
    taxon_photos.in_groups_of( 100, false ) do | taxon_photos_group |
      embeddings_json = embeddings_for_taxon_photos( taxon_photos_group )
      next if embeddings_json.blank?

      taxon_photos_group.each do | taxon_photo |
        taxon_photo.calculated_embedding = embeddings_json[taxon_photo.id.to_s] || {}
      end
    end
  end

  def self.prune_batch_for_index( batch )
    existing_indexed_documents = TaxonPhoto.elastic_mget(
      batch.map( &:id ), source: [:id, :photo_id, :photo_file_update_at]
    ).index_by {| d | d["id"] }
    batch.reject do | taxon_photo |
      indexed_doc = existing_indexed_documents[taxon_photo.id]
      # if there is an existing indexed document with the same photo and version, no need to reindex
      next unless indexed_doc
      next unless indexed_doc["photo_id"] == taxon_photo.photo_id
      next unless indexed_doc["photo_file_update_at"].nil? ||
        Time.parse( indexed_doc["photo_file_update_at"] ).floor ==
          taxon_photo.photo&.file_updated_at&.floor

      true
    end
  end

  def self.embeddings_for_taxon_photos( taxon_photos )
    5.times do
      begin
        Timeout.timeout( 20 ) do
          uri = URI.parse( "#{CONFIG.vision_api_url}/embeddings_for_photos" )
          http = Net::HTTP.new( uri.host, uri.port )
          request = Net::HTTP::Post.new(
            uri.request_uri,
            "Content-Type": "application/json"
          )
          request.body = {
            photos: taxon_photos.map do | tp |
              {
                id: tp.id,
                url: tp.photo&.medium_url
              }
            end
          }.to_json
          response = http.request( request )
          if response.code == "200"
            return JSON.parse( response.body )
          end
        end
      rescue StandardError => e
        Rails.logger.debug "[DEBUG] TaxonPhoto.embeddings_for_taxon_photos failed: #{e}"
        sleep( 1 )
      end
    end
    nil
  end
end
