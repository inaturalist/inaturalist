class Observation < ActiveRecord::Base

  include ActsAsElasticModel

  attr_accessor :indexed_tag_names
  attr_accessor :indexed_project_ids

  scope :load_for_index, -> { includes(:user,
    { sounds: :user },
    { photos: :user },
    { taxon: [ :taxon_names ] },
    { observation_field_values: :observation_field } ) }
  settings index: { number_of_shards: 1, analysis: ElasticModel::ANALYSIS } do
    mappings(dynamic: true) do
      indexes :taxon do
        indexes :names do
          indexes :name, index_analyzer: "ascii_snowball_analyzer",
            search_analyzer: "ascii_snowball_analyzer"
        end
      end
      indexes :photos do
        indexes :license_code, index_analyzer: "keyword_analyzer",
          search_analyzer: "keyword_analyzer"
      end
      indexes :sounds do
        indexes :license_code, index_analyzer: "keyword_analyzer",
          search_analyzer: "keyword_analyzer"
      end
      indexes :field_values do
        indexes :name, index_analyzer: "keyword_analyzer",
          search_analyzer: "keyword_analyzer"
        indexes :value, index_analyzer: "keyword_analyzer",
          search_analyzer: "keyword_analyzer"
      end
      indexes :description, index_analyzer: "ascii_snowball_analyzer",
        search_analyzer: "ascii_snowball_analyzer"
      indexes :tags, index_analyzer: "ascii_snowball_analyzer",
        search_analyzer: "ascii_snowball_analyzer"
      indexes :place_guess, index_analyzer: "ascii_snowball_analyzer",
        search_analyzer: "ascii_snowball_analyzer"
      indexes :species_guess, index_analyzer: "keyword_analyzer",
        search_analyzer: "keyword_analyzer"
      indexes :license_code, index_analyzer: "keyword_analyzer",
        search_analyzer: "keyword_analyzer"
      indexes :observed_on_string, type: "string"
      indexes :location, type: "geo_point", lat_lon: true, geohash: true, geohash_precision: 10
      indexes :private_location, type: "geo_point", lat_lon: true
      indexes :geojson, type: "geo_shape"
      indexes :private_geojson, type: "geo_shape"
    end
  end

  def as_indexed_json(options={})
    preload_for_elastic_index
    {
      id: id,
      created_at: created_at,
      created_at_details: ElasticModel.date_details(created_at),
      updated_at: updated_at,
      observed_on: (Time.parse(observed_on_string) rescue observed_on),
      observed_on_details: ElasticModel.date_details(observed_on),
      site_id: site_id,
      uri: uri,
      description: description,
      mappable: mappable,
      species_guess: species_guess,
      place_guess: place_guess,
      observed_on_string: observed_on_string,
      quality_grade: quality_grade,
      id_please: id_please,
      out_of_range: out_of_range,
      captive: captive,
      license_code: license,
      geoprivacy: geoprivacy,
      num_identification_agreements: num_identification_agreements,
      num_identification_disagreements: num_identification_disagreements,
      identifications_most_agree:
        (num_identification_agreements > num_identification_disagreements),
      identifications_some_agree:
        (num_identification_agreements > 0),
      identifications_most_disagree:
        (num_identification_agreements < num_identification_disagreements),
      project_ids: (indexed_project_ids || project_observations.map(&:project_id)).compact.uniq,
      tags: (indexed_tag_names || tags.map(&:name)).compact.uniq,
      user: user ? user.as_indexed_json : nil,
      taxon: taxon ? taxon.as_indexed_json(basic: true) : nil,
      field_values: observation_field_values.uniq.map(&:as_indexed_json),
      photos: photos.map(&:as_indexed_json),
      sounds: sounds.map(&:as_indexed_json),
      location: (latitude && longitude) ?
        ElasticModel.point_latlon(latitude, longitude) : nil,
      private_location: (private_latitude && private_longitude) ?
        ElasticModel.point_latlon(private_latitude, private_longitude) : nil,
      geojson: ElasticModel.geom_geojson(geom),
      private_geojson: ElasticModel.geom_geojson(private_geom)
    }
  end

  # to quickly fetch tag names and project_ids when bulk indexing
  def self.prepare_batch_for_index(observations)
    # make sure we default all caches to empty arrays
    # this prevents future lookups for instances with no results
    observations.each{ |o|
      o.indexed_tag_names ||= [ ]
      o.indexed_project_ids ||= [ ]
    }
    observations_by_id = Hash[ observations.map{ |o| [ o.id, o ] } ]
    batch_ids_string = observations_by_id.keys.join(",")
    # fetch all tag names store them in `indexed_tag_names`
    connection.execute("
      SELECT ts.taggable_id, t.name
      FROM taggings ts
      JOIN tags t ON (ts.tag_id = t.id)
      WHERE ts.taggable_type='Observation' AND
      ts.taggable_id IN (#{ batch_ids_string })").to_a.each do |r|
      if o = observations_by_id[ r["taggable_id"].to_i ]
        o.indexed_tag_names << r["name"]
      end
    end
    # fetch all project_ids store them in `indexed_project_ids`
    connection.execute("
      SELECT observation_id, project_id
      FROM project_observations
      WHERE observation_id IN (#{ batch_ids_string })").to_a.each do |r|
      if o = observations_by_id[ r["observation_id"].to_i ]
        o.indexed_project_ids << r["project_id"].to_i
      end
    end
  end

end
