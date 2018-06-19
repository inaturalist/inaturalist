class Place < ActiveRecord::Base

  include ActsAsElasticModel

  DEFAULT_ES_BATCH_SIZE = 100

  # some places have geometries that are valid according to PostGIS,
  # but are not being indexed by ES, causing the entire document to
  # not get idexed. This is a fallback method that will disable
  # geometry indexing and try again if the first index failed
  after_commit :double_check_index
  attr_accessor :index_without_geometry

  scope :load_for_index, -> { includes([ :place_geometry, { user: :flags } ]) }
  settings index: { number_of_shards: 1, analysis: ElasticModel::ANALYSIS } do
    mappings(dynamic: true) do
      indexes :id, type: "integer"
      indexes :slug, type: "keyword"
      indexes :name, type: "text", analyzer: "ascii_snowball_analyzer"
      indexes :place_type, type: "integer"
      indexes :geometry_geojson, type: "geo_shape"
      indexes :bounding_box_geojson, type: "geo_shape"
      indexes :location, type: "geo_point"
      indexes :point_geojson, type: "geo_shape"
      indexes :bbox_area, type: "double"
      indexes :display_name, type: "text", analyzer: "ascii_snowball_analyzer"
      indexes :display_name_autocomplete, type: "text",
        analyzer: "keyword_autocomplete_analyzer",
        search_analyzer: "keyword_analyzer"
      indexes :user do
        indexes :login, type: "keyword"
      end
    end
  end

  def as_indexed_json(options={})
    preload_for_elastic_index
    obs_result = INatAPIService.observations( per_page: 0, verifiable: true, place_id: id )
    {
      id: id,
      slug: slug,
      name: name,
      display_name: display_name,
      display_name_autocomplete: display_name,
      place_type: place_type,
      admin_level: admin_level,
      bbox_area: bbox_area,
      ancestor_place_ids: ancestor_place_ids,
      user: user ? user.as_indexed_json(no_details: true) : nil,
      geometry_geojson: (place_geometry && place_geometry.persisted? && !index_without_geometry) ?
        ElasticModel.geom_geojson(place_geometry.simplified_geom) : nil,
      bounding_box_geojson: ( place_geometry && place_geometry.persisted? && !index_without_geometry ) ?
        ElasticModel.geom_geojson( place_geometry.bounding_box_geom ) : nil,
      location: ElasticModel.point_latlon(latitude, longitude),
      point_geojson: ElasticModel.point_geojson(latitude, longitude),
      without_check_list: check_list_id.blank? ? true : nil,
      observations_count: obs_result ? obs_result.total_results : nil
    }
  end

  def geom_in_elastic_index?
    # need to make sure Elasticsearch has refreshed with all
    # changes before checking if this Place record exists
    Place.__elasticsearch__.refresh_index!
    Place.elastic_search(filters: [
      { term: { id: id } },
      { exists: { field: "geometry_geojson" } } ]).total_entries > 0
  end

  def double_check_index
    return if destroyed?
    unless geom_in_elastic_index?
      original_index_without_geometry = self.index_without_geometry
      self.index_without_geometry = true
      self.elastic_index!
      self.index_without_geometry = original_index_without_geometry
    end
  end

end
