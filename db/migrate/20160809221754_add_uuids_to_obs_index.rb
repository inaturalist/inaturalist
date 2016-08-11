class AddUuidsToObsIndex < ActiveRecord::Migration
  def up
    options = {
      index: Observation.index_name,
      type: Observation.document_type,
      body: { }
    }
    options[:body][Observation.document_type] = {
      properties: {
        uuid: { type: "string", analyzer: "keyword_analyzer" },
        comments: {
          properties: { uuid: { type: "string", analyzer: "keyword_analyzer" } }
        },
        project_observations: {
          properties: { uuid: { type: "string", analyzer: "keyword_analyzer" } }
        },
        observation_photos: {
          properties: { uuid: { type: "string", analyzer: "keyword_analyzer" } }
        },
        non_owner_ids: {
          type: "nested",
          properties: { uuid: { type: "string", analyzer: "keyword_analyzer" } }
        },
        ofvs: {
          type: "nested",
          properties: { uuid: { type: "string", analyzer: "keyword_analyzer" } }
        }
      }
    }
    Observation.__elasticsearch__.client.indices.put_mapping(options)
  end

  def down
    # irreversible
  end
end
