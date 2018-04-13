class AddToObservationsIndex < ActiveRecord::Migration
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
            flags: {
              properties: {
                flag: { type: "keyword" }
              }
            }
          }
        },
        flags: {
          properties: {
            flag: { type: "keyword" }
          }
        },
        identifications: {
          type: "nested",
          properties: {
            uuid: { type: "keyword" },
            body: { type: "text", analyzer: "ascii_snowball_analyzer" },
            category: { type: "keyword" },
            user: {
              properties: {
                login: { type: "keyword" }
              }
            },
            taxon_change: {
              properties: {
                type: { type: "keyword" }
              }
            },
            flags: {
              properties: {
                flag: { type: "keyword" }
              }
            }
          }
        },
        photos: {
          properties: {
            flags: {
              properties: {
                flag: { type: "keyword" }
              }
            }
          }
        },
        preferences: {
          properties: {
            name: { type: "keyword", index: false },
            value: { type: "keyword", index: false }
          }
        },
        project_observations: {
          properties: {
            preferences: {
              properties: {
                name: { type: "keyword", index: false },
                value: { type: "keyword", index: false }
              }
            }
          }
        },
        quality_metrics: {
          properties: {
            metric: { type: "keyword", index: false }
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
