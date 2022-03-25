class ObservationField < ApplicationRecord

  include ActsAsElasticModel

  settings index: { number_of_shards: 1, analysis: ElasticModel::ANALYSIS } do
    mappings(dynamic: true) do
      indexes :allowed_values, type: "keyword"
      indexes :datatype, type: "keyword"
      indexes :description, type: "text", analyzer: "ascii_snowball_analyzer"
      indexes :description_autocomplete, type: "text",
        analyzer: "autocomplete_analyzer",
        search_analyzer: "standard_analyzer"
      indexes :id, type: "integer" do
        indexes :keyword, type: "keyword"
      end
      indexes :name, type: "text", analyzer: "ascii_snowball_analyzer"
      indexes :name_autocomplete, type: "text",
        analyzer: "autocomplete_analyzer",
        search_analyzer: "standard_analyzer"
      indexes :users_count, type: "integer"
      indexes :values_count, type: "integer"
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
