class AddNestedMappingsToObservationsIndex < ActiveRecord::Migration
  def up
    # this is a near duplicate of AddMappingsToObservationsIndex with different
    # field names because I [pleary] botched it the first time around
    # and we ended up adding data before the migration was run, so the
    # fields were not of type: nested. I'll clean up this mess eventually
    # by rebuilding the indices entirely
    options = {
      index: Observation.index_name,
      type: Observation.document_type,
      body: { }
    }
    options[:body][Observation.document_type] = {
      properties: {
        ofvs: {
          type: "nested",
          properties: {
            name: { type: "string", analyzer: "keyword_analyzer" },
            value: { type: "string", analyzer: "keyword_analyzer" }
          }
        },
        taxon: {
          properties: {
            statuses: {
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
