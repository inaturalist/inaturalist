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

  settings index: { number_of_shards: 4, analysis: ElasticModel::ANALYSIS } do
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
    {
      id: id,
      created_at: created_at,
      votes: votes_for.map( &:as_indexed_json ),
      cached_votes_total:
        votes_for.select( &:vote_flag? ).size - votes_for.reject( &:vote_flag? ).size,
      nominated_by_user_id: nominated_by_user_id,
      nominated_at: nominated_at,
      identification: {
        id: identification.id,
        uuid: identification.uuid,
        body: identification.body,
        body_word_length:
          identification.body.blank? ? 0 : identification.body.split( /\s+/ ).length,
        body_character_length:
          identification.body.blank? ? 0 : identification.body.length,
        created_at: identification.created_at,
        user: {
          id: identification.user_id
        },
        observation: if identification.observation
                       {
                         id: identification.observation.id,
                         discussion_count: identification.observation.comments.size +
                           + identification.observation.identifications.filter do | identification |
                             !identification.body&.strip.blank?
                           end.size,
                         taxon: {
                           id: identification.observation.taxon&.id,
                           ancestor_ids: ( (
                             identification.observation.taxon&.ancestry ?
                               identification.observation.taxon.ancestry.split( "/" ).map( &:to_i ) : []
                           ) << identification.observation.taxon&.id ).compact
                         },
                         annotations: identification.observation.annotations.
                           reject( &:term_taxon_mismatch? ).map do | annotation |
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
        end,
        taxon: if identification.taxon
                 {
                   id: identification.taxon.id,
                   ancestor_ids: ( (
                     identification.taxon.ancestry ?
                       identification.taxon.ancestry.split( "/" ).map( &:to_i ) : []
                   ) << id )
                 }
        end
      }
    }
  end
end
