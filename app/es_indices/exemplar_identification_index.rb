# frozen_string_literal: true

class ExemplarIdentification < ApplicationRecord
  acts_as_elastic_model

  DEFAULT_ES_BATCH_SIZE = 500

  scope :load_for_index, lambda {
    includes(
      :votes_for,
      identification: [
        :user,
        :taxon,
        { observation: [
          :comments,
          :identifications,
          :user,
          :taxon,
          { annotations: :votes_for }
        ] }
      ]
    )
  }

  settings index: {
    number_of_shards: 4,
    analysis: ElasticModel::ANALYSIS
  } do
    mappings( dynamic: false ) do
      indexes :id, type: "integer" do
        indexes :keyword, type: "keyword"
      end
      indexes :created_at, type: "date"
      indexes :votes, type: :nested do
        indexes :created_at, type: "date"
        indexes :id, type: "integer"
        indexes :user_id, type: "integer"
        indexes :vote_flag, type: "boolean"
      end
      indexes :cached_votes_total, type: "short"
      indexes :nominated_by_user_id, type: "integer" do
        indexes :keyword, type: "keyword"
      end
      indexes :nominated_at, type: "date"
      indexes :active, type: "boolean"
      indexes :identification do
        indexes :id, type: "integer" do
          indexes :keyword, type: "keyword"
        end
        indexes :uuid, type: "keyword"
        indexes :body, type: "text", analyzer: "ascii_snowball_analyzer"
        indexes :body_word_length, type: "integer"
        indexes :body_character_length, type: "integer"
        indexes :created_at, type: "date"
        indexes :user do
          indexes :id, type: "integer" do
            indexes :keyword, type: "keyword"
          end
        end
        indexes :observation do
          indexes :id, type: "integer"
          indexes :discussion_count, type: "short"
          indexes :taxon do
            indexes :ancestor_ids, type: "integer" do
              indexes :keyword, type: "keyword"
            end
            indexes :id, type: "integer" do
              indexes :keyword, type: "keyword"
            end
          end
          indexes :annotations, type: :nested do
            indexes :uuid, type: "keyword"
            indexes :concatenated_attr_val, type: "keyword"
            indexes :controlled_attribute_id, type: "short" do
              indexes :keyword, type: "keyword"
            end
            indexes :controlled_value_id, type: "short" do
              indexes :keyword, type: "keyword"
            end
          end
        end
        indexes :taxon do
          indexes :ancestor_ids, type: "integer" do
            indexes :keyword, type: "keyword"
          end
          indexes :id, type: "integer" do
            indexes :keyword, type: "keyword"
          end
        end
      end
    end
  end

  def as_indexed_json( _options = {} )
    observation = identification.observation
    observation_schema = if observation
      {
        id: observation.id,
        discussion_count: observation.comments.size +
          + observation.identifications.filter do | obs_id |
            !obs_id.body&.strip.blank?
          end.size,
        taxon: observation.taxon ? {
          id: observation.taxon.id,
          ancestor_ids: observation.taxon.self_and_ancestor_ids
        } : {},
        annotations: observation.annotations.reject( &:term_taxon_mismatch? ).reject do | a |
          a.vote_score.negative?
        end.map do | annotation |
          {
            uuid: annotation.uuid,
            concatenated_attr_val: [
              annotation.controlled_attribute_id,
              annotation.controlled_value_id
            ].join( "|" ),
            controlled_attribute_id: annotation.controlled_attribute_id,
            controlled_value_id: annotation.controlled_value_id
          }
        end
      }
    end
    {
      id: id,
      created_at: created_at,
      votes: votes_for.map( &:as_indexed_json ),
      cached_votes_total:
        votes_for.select( &:vote_flag? ).size - votes_for.reject( &:vote_flag? ).size,
      nominated_by_user_id: nominated_by_user_id,
      nominated_at: nominated_at,
      active: active,
      identification: {
        id: identification.id,
        uuid: identification.uuid,
        body: identification.body,
        body_word_length: identification.body&.split&.length || 0,
        body_character_length: identification.body&.length || 0,
        created_at: identification.created_at,
        user: {
          id: identification.user_id
        },
        observation: observation_schema,
        taxon: identification.taxon ? {
          id: identification.taxon.id,
          ancestor_ids: identification.taxon.self_and_ancestor_ids
        } : {}
      }
    }
  end
end
