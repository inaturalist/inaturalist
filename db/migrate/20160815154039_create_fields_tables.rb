class CreateFieldsTables < ActiveRecord::Migration
  def change
    create_table :controlled_terms do |t|
      t.text :ontology_uri
      t.text :uri
      t.integer :valid_within_clade
      t.boolean :is_value, default: false
      t.boolean :active, default: false
      t.boolean :multivalued, default: false
      t.integer :user_id
      t.timestamps
    end
    create_table :controlled_term_labels do |t|
      t.integer :controlled_term_id
      t.string :locale
      t.integer :valid_within_clade
      t.string :label
      t.string :definition
      t.string :icon_file_name
      t.string :icon_content_type
      t.string :icon_file_size
      t.string :icon_updated_at
      t.integer :user_id
      t.timestamps
    end
    create_table :controlled_term_values do |t|
      t.integer :controlled_attribute_id
      t.integer :controlled_value_id
    end
    create_table :annotations do |t|
      t.uuid :uuid, default: "uuid_generate_v4()"
      t.integer :resource_id
      t.string :resource_type
      t.integer :controlled_attribute_id
      t.integer :controlled_value_id
      t.integer :user_id
      t.integer :observation_field_value_id
      t.timestamps
    end
    add_index :annotations, [:resource_id, :resource_type]

    # create the `annotations` property for the Observations Elasticsearch
    # index, and make it a nested type with properties with custom analyzers
    options = {
      index: Observation.index_name,
      type: Observation.document_type,
      body: { }
    }
    options[:body][Observation.document_type] = {
      properties: {
        annotations: {
          type: "nested",
          properties: {
            uuid: {
              type: "string",
              analyzer: "keyword_analyzer"
            },
            resource_type: {
              type: "string",
              analyzer: "keyword_analyzer"
            },
            concatenated_attr_val: {
              type: "string",
              analyzer: "keyword_analyzer"
            }
          }
        }
      }
    }
    Observation.__elasticsearch__.client.indices.put_mapping(options)
  end
end
