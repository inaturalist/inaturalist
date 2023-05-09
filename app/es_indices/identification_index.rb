class Identification < ApplicationRecord

  include ActsAsElasticModel

  DEFAULT_ES_BATCH_SIZE = 500

  scope :load_for_index, -> { includes(:taxon, :flags,
    :stored_preferences, :taxon_change, :moderator_actions,
    { observation: [ :taxon, { user: :flags }, :identifications ] },
    { user: :flags } ) }

  settings index: { number_of_shards: Rails.env.production? ? 12 : 4, analysis: ElasticModel::ANALYSIS } do
    mappings(dynamic: true) do
      indexes :body, type: "text", analyzer: "ascii_snowball_analyzer"
      indexes :category, type: "keyword"
      indexes :created_at, type: "date"
      indexes :created_at_details do
        indexes :date, type: "date", index: false
        indexes :day, type: "byte", index: false
        indexes :hour, type: "byte", index: false
        indexes :month, type: "byte", index: false
        indexes :week, type: "byte", index: false
        indexes :year, type: "short", index: false
      end
      indexes :current, type: "boolean"
      indexes :current_taxon, type: "boolean"
      indexes :disagreement, type: "boolean"
      indexes :flags do
        indexes :comment, type: "keyword", index: false
        indexes :created_at, type: "date", index: false
        indexes :flag, type: "keyword", index: false
        indexes :id, type: "integer", index: false
        indexes :resolved, type: "boolean", index: false
        indexes :resolver_id, type: "integer", index: false
        indexes :updated_at, type: "date", index: false
        indexes :user_id, type: "integer", index: false
      end
      indexes :hidden, type: "boolean"
      indexes :id, type: "integer" do
        indexes :keyword, type: "keyword"
      end
      indexes :moderator_actions do
        indexes :action, type: "keyword", index: false
        indexes :created_at, type: "date"
        indexes :created_at_details do
          indexes :date, type: "date", index: false
          indexes :day, type: "byte", index: false
          indexes :hour, type: "byte", index: false
          indexes :month, type: "byte", index: false
          indexes :week, type: "byte", index: false
          indexes :year, type: "short", index: false
        end
        indexes :id, type: "integer"
        indexes :reason, type: "text", analyzer: "ascii_snowball_analyzer", index: false
        indexes :user do
          indexes :created_at, type: "date"
          indexes :id, type: "integer"
          indexes :login, type: "keyword"
          indexes :spam, type: "boolean"
          indexes :suspended, type: "boolean"
        end
      end
      indexes :observation do
        indexes :created_at, type: "date"
        indexes :created_at_details do
          indexes :date, type: "date", index: false
          indexes :day, type: "byte", index: false
          indexes :hour, type: "byte", index: false
          indexes :month, type: "byte", index: false
          indexes :week, type: "byte", index: false
          indexes :year, type: "short", index: false
        end
        indexes :id, type: "integer"
        indexes :observed_on, type: "date", format: "date_optional_time"
        indexes :observed_on_details do
          indexes :date, type: "date", index: false
          indexes :day, type: "byte", index: false
          indexes :hour, type: "byte", index: false
          indexes :month, type: "byte", index: false
          indexes :week, type: "byte", index: false
          indexes :year, type: "short", index: false
        end
        indexes :place_ids, type: "integer" do
          indexes :keyword, type: "keyword"
        end
        indexes :quality_grade, type: "keyword"
        indexes :site_id, type: "integer" do
          indexes :keyword, type: "keyword"
        end
        indexes :taxon do
          indexes :ancestor_ids, type: "integer" do
            indexes :keyword, type: "keyword"
          end
          indexes :iconic_taxon_id, type: "integer" do
            indexes :keyword, type: "keyword"
          end
          indexes :id, type: "integer" do
            indexes :keyword, type: "keyword"
          end
          indexes :is_active, type: "boolean"
          indexes :min_species_ancestry, type: "keyword"
          indexes :min_species_taxon_id, type: "integer"
          indexes :rank, type: "keyword"
          indexes :rank_level, type: "scaled_float", scaling_factor: 100
        end
        indexes :time_observed_at, type: "date"
        indexes :user_id, type: "integer" do
          indexes :keyword, type: "keyword"
        end
      end
      indexes :own_observation, type: "boolean"
      indexes :previous_observation_taxon_id, type: "integer"
      indexes :spam, type: "boolean"
      indexes :taxon do
        indexes :ancestor_ids, type: "integer" do
          indexes :keyword, type: "keyword"
        end
        indexes :iconic_taxon_id, type: "integer" do
          indexes :keyword, type: "keyword"
        end
        indexes :id, type: "integer" do
          indexes :keyword, type: "keyword"
        end
        indexes :is_active, type: "boolean"
        indexes :min_species_ancestry, type: "keyword"
        indexes :min_species_taxon_id, type: "integer"
        indexes :rank, type: "keyword"
        indexes :rank_level, type: "scaled_float", scaling_factor: 100
      end
      indexes :taxon_change do
        indexes :id, type: "integer"
        indexes :type, type: "keyword"
      end
      indexes :taxon_id, type: "integer"
      indexes :user do
        indexes :created_at, type: "date"
        indexes :id, type: "integer" do
          indexes :keyword, type: "keyword"
        end
        indexes :login, type: "keyword"
        indexes :spam, type: "boolean"
        indexes :suspended, type: "boolean"
      end
      indexes :uuid, type: "keyword"
      indexes :vision, type: "boolean"
    end
  end

  def as_indexed_json(options={})
    json = {
      id: id,
      uuid: uuid,
      user: user ? user.as_indexed_json(no_details: true) : nil,
      created_at: created_at,
      created_at_details: ElasticModel.date_details(created_at),
      body: body,
      category: category,
      current: current,
      flags: flags.map(&:as_indexed_json),
      own_observation: observation ? (user_id == observation.user_id) : false,
      taxon_change: taxon_change ? {
        id: taxon_change.id,
        type: taxon_change.type
      } : nil,
      vision: vision,
      disagreement: disagreement,
      previous_observation_taxon_id: previous_observation_taxon_id,
      spam: known_spam? || owned_by_spammer?,
      taxon_id: taxon_id,
      hidden: hidden?
    }
    if observation && taxon && !options[:no_details]
      json.merge!({
        current_taxon: (taxon_id == observation.taxon_id),
        taxon: taxon.as_indexed_json(no_details: true, for_identification: true),
        observation: observation.as_indexed_json(no_details: true, for_identification: true),
        moderator_actions: moderator_actions.map(&:as_indexed_json)
      })
    end
    json
  end

  def self.prepare_batch_for_index(identifications)
    obs = identifications.map(&:observation).compact
    # bulk load the IDs' observations' places
    Observation.prepare_batch_for_index(obs, { places: true })
  end
end
