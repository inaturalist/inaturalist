class AddNonOwnerIdsToObservationsIndex < ActiveRecord::Migration
  def up
    options = {
      index: Observation.index_name,
      type: Observation.document_type,
      body: { }
    }
    options[:body][Observation.document_type] = {
      properties: {
        non_owner_ids: {
          type: "nested"
        }
      }
    }
    Observation.__elasticsearch__.client.indices.put_mapping(options)
  end

  def down
    # irreversible
  end
end
