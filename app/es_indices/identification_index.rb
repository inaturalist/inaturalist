class Identification < ActiveRecord::Base

  include ActsAsElasticModel

  scope :load_for_index, -> { includes(:taxon,
    { observation: [ :taxon, :user ] }, :user) }

  settings index: { number_of_shards: 1, analysis: ElasticModel::ANALYSIS } do
    mappings(dynamic: true) do
      indexes :uuid, analyzer: "keyword_analyzer"
      indexes :body, analyzer: "ascii_snowball_analyzer"
      indexes :category, analyzer: "keyword_analyzer"
    end
  end

  def as_indexed_json(options={})
    created = created_at.in_time_zone((observation && observation.timezone_object) || "UTC")
    json = {
      id: id,
      uuid: uuid,
      user: user ? user.as_indexed_json(no_details: true) : nil,
      created_at: created_at,
      created_at_details: ElasticModel.date_details(created_at),
      body: body,
      category: category,
      current: current
    }
    if observation && taxon && !options[:no_details]
      json.merge!({
        own_observation: (user_id == observation.user_id),
        current_taxon: (taxon_id == observation.taxon_id),
        taxon: taxon.as_indexed_json(no_details: true, for_identification: true),
        observation: observation.as_indexed_json(no_details: true)
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
