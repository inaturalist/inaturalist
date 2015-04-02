class Place < ActiveRecord::Base

  include ActsAsElasticModel

  scope :load_for_index, -> { includes(:place_geometry) }
  settings index: { number_of_shards: 1, analysis: ElasticModel::ANALYSIS } do
    mappings(dynamic: true) do
      indexes :geometry_geojson, type: "geo_shape"
      indexes :location, type: "geo_point"
      indexes :point_geojson, type: "geo_shape"
      indexes :bbox_area, type: "double"
      indexes :display_name, index_analyzer: "ascii_snowball_analyzer",
        search_analyzer: "ascii_snowball_analyzer"
      indexes :display_name_autocomplete, index_analyzer: "keyword_autocomplete_analyzer",
        search_analyzer: "keyword_analyzer"
    end
  end

  def as_indexed_json(options={})
    preload_for_elastic_index
    {
      id: id,
      name: name,
      display_name: display_name,
      display_name_autocomplete: display_name,
      place_type: place_type,
      bbox_area: bbox_area,
      ancestor_place_ids: ancestor_place_ids,
      geometry_geojson: place_geometry ?
        ElasticModel.geom_geojson(place_geometry.geom) : nil,
      location: ElasticModel.point_latlon(latitude, longitude),
      point_geojson: ElasticModel.point_geojson(latitude, longitude)
    }
  end

end
