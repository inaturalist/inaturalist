class Place < ActiveRecord::Base

  include ActsAsElasticModel

  # some places have geometries that are valid according to PostGIS,
  # but are not being indexed by ES, causing the entire document to
  # not get idexed. This is a fallback method that will disable
  # geometry indexing and try again if the first index failed
  after_commit :double_check_index
  attr_accessor :index_without_geometry

  scope :load_for_index, -> { includes(:place_geometry) }
  settings index: { number_of_shards: 1, analysis: ElasticModel::ANALYSIS } do
    mappings(dynamic: true) do
      indexes :id, type: "integer"
      indexes :place_type, type: "integer"
      indexes :geometry_geojson, type: "geo_shape"
      indexes :location, type: "geo_point", lat_lon: true
      indexes :point_geojson, type: "geo_shape"
      indexes :bbox_area, type: "double"
      indexes :display_name, analyzer: "ascii_snowball_analyzer"
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
      geometry_geojson: (place_geometry && !index_without_geometry) ?
        ElasticModel.geom_geojson(place_geometry.geom) : nil,
      location: ElasticModel.point_latlon(latitude, longitude),
      point_geojson: ElasticModel.point_geojson(latitude, longitude)
    }
  end

  def geom_in_elastic_index
    Place.elastic_search(where: { id: id },
      filters: [ { exists: { field: "geometry_geojson" } } ]).
      total_entries > 0
  end

  def double_check_index
    unless geom_in_elastic_index
      self.index_without_geometry = true
      self.elastic_index!
    end
  end

end
