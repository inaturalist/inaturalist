class Project < ActiveRecord::Base

  include ActsAsElasticModel

  scope :load_for_index, -> { includes(:place) }
  settings index: { number_of_shards: 1, analysis: ElasticModel::ANALYSIS } do
    mappings(dynamic: true) do
      indexes :title, analyzer: "ascii_snowball_analyzer"
      indexes :title_autocomplete, analyzer: "autocomplete_analyzer",
        search_analyzer: "standard_analyzer"
      indexes :description, analyzer: "ascii_snowball_analyzer"
      indexes :slug, analyzer: "keyword_analyzer"
      indexes :location, type: "geo_point", lat_lon: true
      indexes :geojson, type: "geo_shape"
    end
  end

  def as_indexed_json(options={})
    preload_for_elastic_index
    {
      id: id,
      title: title,
      title_autocomplete: title,
      description: description,
      slug: slug,
      ancestor_place_ids: place ? place.ancestor_place_ids : nil,
      place_ids: place ? place.self_and_ancestor_ids : nil,
      location: ElasticModel.point_latlon(latitude, longitude),
      geojson: ElasticModel.point_geojson(latitude, longitude)
    }
  end

end
