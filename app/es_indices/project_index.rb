class Project < ActiveRecord::Base

  include ActsAsElasticModel

  DEFAULT_ES_BATCH_SIZE = 500

  scope :load_for_index, -> { includes(:place, :project_users, :observation_fields) }

  settings index: { number_of_shards: 1, analysis: ElasticModel::ANALYSIS } do
    mappings(dynamic: true) do
      indexes :icon, type: "keyword", index: false
      indexes :title, analyzer: "ascii_snowball_analyzer"
      indexes :title_autocomplete, analyzer: "autocomplete_analyzer",
        search_analyzer: "standard_analyzer"
      indexes :title_exact, type: "keyword"
      indexes :description, analyzer: "ascii_snowball_analyzer"
      indexes :slug, analyzer: "keyword_analyzer"
      indexes :location, type: "geo_point"
      indexes :geojson, type: "geo_shape"
    end
  end

  def as_indexed_json(options={})
    preload_for_elastic_index
    {
      id: id,
      title: title,
      title_autocomplete: title,
      title_exact: title,
      description: description,
      slug: slug,
      ancestor_place_ids: place ? place.ancestor_place_ids : nil,
      place_ids: place ? place.self_and_ancestor_ids : nil,
      user_ids: project_users.map(&:user_id).sort,
      location: ElasticModel.point_latlon(latitude, longitude),
      geojson: ElasticModel.point_geojson(latitude, longitude),
      icon: icon ? icon.url(:span2) : nil,
      project_observation_fields: project_observation_fields.map(&:as_indexed_json)
    }
  end

end
