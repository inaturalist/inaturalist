# frozen_string_literal: true

class TaxonPhoto < ApplicationRecord
  scope :load_for_qdrant_index, -> { load_for_index }

  qdrant_collection_settings(
    collection_parameters: {
      on_disk_payload: true,
      vectors: {
        size: 2048,
        distance: "Cosine",
        on_disk: true
      },
      quantization_config: {
        scalar: {
          type: "int8",
          quantile: 0.99,
          always_ram: true
        }
      },
      hnsw_config: {
        m: 16,
        ef_construct: 100,
        on_disk: true
      }
    },
    payload_indices: {
      ancestor_ids: {
        type: "integer",
        lookup: true,
        range: false,
        is_principal: true
      }
    }
  )

  def as_qdrant_json
    TaxonPhoto.prepare_batch_for_qdrant_index( [self] ) unless calculated_embedding

    return nil if calculated_embedding.blank?

    {
      id: id,
      vector: calculated_embedding,
      payload: {
        id: id,
        taxon_id: taxon_id,
        photo_id: photo_id,
        photo_file_updated_at: photo&.file_updated_at,
        ancestor_ids: taxon&.self_and_ancestor_ids
      }
    }
  end

  def self.prepare_batch_for_qdrant_index( taxon_photos )
    prepare_batch_for_index( taxon_photos )
  end

  def self.prune_batch_for_qdrant_index( batch )
    existing_indexed_documents = TaxonPhoto.qdrant_get_all( batch.map( &:id ) ).index_by {| d | d["id"] }
    batch.select {| taxon_photo | taxon_photo&.taxon&.is_active? }.
      reject do | taxon_photo |
      indexed_doc = existing_indexed_documents[taxon_photo.id]
      # if there is an existing indexed document with the same taxon ancestors,
      # and the same photo and version, no need to reindex
      next unless indexed_doc

      payload = indexed_doc["payload"]
      next unless payload["ancestor_ids"] && taxon_photo&.taxon &&
        payload["ancestor_ids"].sort == taxon_photo.taxon.self_and_ancestor_ids&.sort
      next unless payload["photo_id"] == taxon_photo.photo_id
      next unless (
        payload["photo_file_updated_at"].blank? && taxon_photo.photo&.file_updated_at.blank?
      ) || Time.parse( payload["photo_file_updated_at"] ).floor ==
        taxon_photo.photo&.file_updated_at&.floor

      true
    end
  end
end
