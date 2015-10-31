class AddMappingsToObservationsIndex < ActiveRecord::Migration
  def up
    # adding new nested types:
    #   - observation.observation_field_values.[name, value]
    #   - observation.taxon.conservation_statuses.[authority, status]
    #
    # See https://www.elastic.co/guide/en/elasticsearch/reference/current/nested.html
    # for more info on nested types and how to query them
    options = {
      index: Observation.index_name,
      type: Observation.document_type,
      body: { }
    }
    options[:body][Observation.document_type] = {
      properties: {
        observation_field_values: {
          type: "nested",
          properties: {
            name: { type: "string", analyzer: "keyword_analyzer" },
            value: { type: "string", analyzer: "keyword_analyzer" }
          }
        },
        taxon: {
          properties: {
            conservation_statuses: {
              type: "nested",
              properties: {
                authority: { type: "string", analyzer: "keyword_analyzer" },
                status: { type: "string", analyzer: "keyword_analyzer" }
              }
            }
          }
        }
      }
    }
    Observation.__elasticsearch__.client.indices.put_mapping(options)
  end

  def down
    # irreversible
  end
end
