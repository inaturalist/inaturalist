# frozen_string_literal: true

class TaxonIdentification < Identification
  acts_as_elastic_model initialize: true

  DEFAULT_ES_BATCH_SIZE = 500

  scope :load_for_index, lambda {
    includes(
      :user, :taxon, :votes_for,
      observation: [
        :user,
        :taxon,
        { annotations: :votes_for }
      ]
    )
  }

  settings index: { number_of_shards: 1, analysis: ElasticModel::ANALYSIS } do
    mappings( dynamic: true ) do
      indexes :id, type: "integer" do
        indexes :keyword, type: "keyword"
      end
      indexes :body, type: "text", analyzer: "ascii_snowball_analyzer"
      indexes :created_at, type: "date"
      indexes :user do
        indexes :id, type: "integer" do
          indexes :keyword, type: "keyword"
        end
      end
      indexes :observation do
        indexes :id, type: "integer"
        indexes :taxon do
          indexes :ancestor_ids, type: "integer" do
            indexes :keyword, type: "keyword"
          end
          indexes :id, type: "integer" do
            indexes :keyword, type: "keyword"
          end
        end
        indexes :user do
          indexes :id, type: "integer" do
            indexes :keyword, type: "keyword"
          end
        end
        indexes :annotations, type: :nested do
          indexes :concatenated_attr_val, type: "keyword"
          indexes :controlled_attribute_id, type: "short" do
            indexes :keyword, type: "keyword"
          end
          indexes :controlled_value_id, type: "short" do
            indexes :keyword, type: "keyword"
          end
          indexes :resource_type, type: "keyword"
          indexes :uuid, type: "keyword"
          indexes :user_id, type: "keyword"
          indexes :vote_score_short, type: "short"
          indexes :votes do
            indexes :created_at, type: "date", index: false
            indexes :id, type: "integer", index: false
            indexes :user_id, type: "integer", index: false
            indexes :vote_flag, type: "boolean", index: false
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
      indexes :votes, type: :nested do
        indexes :created_at, type: "date"
        indexes :id, type: "integer"
        indexes :user_id, type: "integer"
        indexes :vote_flag, type: "boolean"
      end
    end
  end
end
