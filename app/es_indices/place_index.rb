class Place < ApplicationRecord

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
      indexes :admin_level, type: "short"
      indexes :ancestor_place_ids, type: "integer"
      indexes :bbox_area, type: "float"
      indexes :bounding_box_geojson, type: "geo_shape"
      indexes :display_name, type: "text", analyzer: "ascii_snowball_analyzer"
      indexes :display_name_autocomplete, type: "text",
        analyzer: "keyword_autocomplete_analyzer",
        search_analyzer: "keyword_analyzer"
      indexes :geometry_geojson, type: "geo_shape"
      indexes :id, type: "integer" do
        indexes :keyword, type: "keyword"
      end
      indexes :location, type: "geo_point"
      indexes :name, type: "text", analyzer: "ascii_snowball_analyzer"
      indexes :observations_count, type: "integer"
      indexes :place_type, type: "integer"
      indexes :point_geojson, type: "geo_shape"
      indexes :slug, type: "keyword"
      indexes :universal_search_rank, type: "integer"
      indexes :user do
        indexes :created_at, type: "date"
        indexes :id, type: "integer"
        indexes :login, type: "keyword"
        indexes :spam, type: "boolean"
        indexes :suspended, type: "boolean"
      end
      indexes :without_check_list, type: "boolean"
      indexes :names, type: :nested do
        indexes :exact, type: "keyword"
        indexes :exact_ci, type: "text", analyzer: "keyword_analyzer"
        indexes :locale, type: "keyword"
        indexes :name, type: "text", analyzer: "ascii_snowball_analyzer"
        indexes :name_autocomplete, type: "text",
          analyzer: "autocomplete_analyzer",
          search_analyzer: "standard_analyzer"
        indexes :name_autocomplete_ja, type: "text", analyzer: "autocomplete_analyzer_ja"
        indexes :name_ja, type: "text", analyzer: "kuromoji"
      end
    end
  end

  def as_indexed_json(options={})
    preload_for_elastic_index
    universal_search_rank = if obs_result = INatAPIService.observations( per_page: 0, verifiable: true, place_id: id )
      if admin_level.nil?
        obs_result.total_results / 2
      else
        obs_result.total_results
      end
    else
      nil
    end
    # Compile translated names to match the similar structure in the taxa index
    names = []
    I18N_SUPPORTED_LOCALES.each do |locale|
      locale_name = translated_name( locale )
      if locale_name && locale_name != name
        name_json = {
          exact: locale_name,
          exact_ci: locale_name,
          locale: locale,
          name: locale_name,
          name_autocomplete: locale_name
        }
        if locale.to_s == "ja"
          name_json[:name_autocomplete_ja] = locale_name
          name_json[:name_ja] = locale_name
        end
        names << name_json
      end
    end
    {
      id: id,
      uuid: uuid,
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
        bounding_box_geojson : nil,
      location: ElasticModel.point_latlon(latitude, longitude),
      point_geojson: ElasticModel.point_geojson(latitude, longitude),
      without_check_list: check_list_id.blank? ? true : nil,
      observations_count: universal_search_rank,
      universal_search_rank: universal_search_rank,
      names: names
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
