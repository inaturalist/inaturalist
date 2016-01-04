class EditObservationsIndexMapping < ActiveRecord::Migration
  def up
    options = {
      index: Observation.index_name,
      type: Observation.document_type,
      body: { }
    }
    options[:body][Observation.document_type] = {
      properties: {
        comments: {
          properties: {
            body: { type: "string", analyzer: "ascii_snowball_analyzer" }
          }
        },
        identifications: {
          properties: {
            body: { type: "string", analyzer: "ascii_snowball_analyzer" }
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
