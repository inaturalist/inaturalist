class AddFieldChangeTimesToObsIndex < ActiveRecord::Migration
  def up
    # define a new Observation elasticsearch mapping as a nested type
    options = {
      index: Observation.index_name,
      type: Observation.document_type,
      body: { }
    }
    options[:body][Observation.document_type] = {
      properties: {
        field_change_times: {
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
