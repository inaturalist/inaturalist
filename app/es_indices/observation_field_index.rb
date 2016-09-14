class ObservationField < ActiveRecord::Base

  include ActsAsElasticModel

  settings index: { number_of_shards: 1, analysis: ElasticModel::ANALYSIS } do
    mappings(dynamic: true) do
      indexes :name, analyzer: "ascii_snowball_analyzer"
      indexes :name_autocomplete, analyzer: "autocomplete_analyzer",
        search_analyzer: "standard_analyzer"
      indexes :description, analyzer: "ascii_snowball_analyzer"
      indexes :description_autocomplete, analyzer: "autocomplete_analyzer",
        search_analyzer: "standard_analyzer"
    end
  end

  def as_indexed_json(options={})
    return {
      id: id,
      name: name,
      name_autocomplete: name,
      description: description,
      description_autocomplete: description,
      datatype: datatype,
      allowed_values: allowed_values,
      values_count: values_count,
      users_count: users_count
    }
  end

end
