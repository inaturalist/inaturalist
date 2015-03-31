class Project < ActiveRecord::Base

  acts_as_elastic_model
  scope :load_for_index, -> { includes(:place) }
  settings index: { number_of_shards: 1, analysis: ElasticModel::ANALYSIS } do
    mappings(dynamic: true) do
      indexes :title, index_analyzer: "ascii_snowball_analyzer",
        search_analyzer: "ascii_snowball_analyzer"
      indexes :title_autocomplete, index_analyzer: "keyword_autocomplete_analyzer",
        search_analyzer: "keyword_analyzer"
      indexes :description, index_analyzer: "ascii_snowball_analyzer",
        search_analyzer: "ascii_snowball_analyzer"
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
      description: description,
      ancestor_place_ids: place ? place.ancestor_place_ids : nil,
      location: ElasticModel.point_latlon(latitude, longitude),
      geojson: ElasticModel.point_geojson(latitude, longitude)
    }
  end

end
