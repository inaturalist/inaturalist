class Observation < ActiveRecord::Base

  include ActsAsElasticModel

  scope :load_for_index, -> { includes(:user, :tags,
    :project_observations,
    { sounds: :user },
    { photos: :user },
    { taxon: [ :taxon_names, :taxon_descriptions, :colors ] },
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
      indexes :location, type: "geo_point", lat_lon: true
      indexes :geojson, type: "geo_shape"
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
      num_identification_agreements: num_identification_agreements,
      num_identification_disagreements: num_identification_disagreements,
      identifications_most_agree: (num_identification_agreements > num_identification_disagreements),
      identifications_some_agree: (num_identification_agreements > 0),
      identifications_most_disagree: (num_identification_agreements < num_identification_disagreements),
      project_ids: project_observations.map(&:project_id),
      tags: tags.map(&:name).uniq,
      user: user ? user.as_indexed_json : nil,
      taxon: taxon ? taxon.as_indexed_json(basic: true) : nil,
      field_values: observation_field_values.map(&:as_indexed_json),
      photos: photos.map(&:as_indexed_json),
      sounds: sounds.map(&:as_indexed_json),
      location: if (private_latitude && private_longitude)
          ElasticModel.point_latlon(private_latitude, private_longitude)
        elsif (latitude && longitude)
          ElasticModel.point_latlon(latitude, longitude)
        else
          nil
        end,
      geojson: ElasticModel.geom_geojson(private_geom || geom)
    }
  end

end
