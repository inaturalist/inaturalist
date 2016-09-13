class CreateFieldsTables < ActiveRecord::Migration
  def change
    create_table :controlled_terms do |t|
      t.text :ontology_uri
      t.text :uri
      t.string :label
      t.string :definition
      t.integer :valid_within_clade
      t.string :icon_file_name
      t.string :icon_content_type
      t.string :icon_file_size
      t.string :icon_updated_at
      t.boolean :is_value, default: false
      t.boolean :active, default: false
      t.integer :user_id
    end
    create_table :controlled_term_values do |t|
      t.integer :controlled_attribute_id
      t.integer :controlled_value_id
    end
    create_table :controlled_terms_resources do |t|
      t.integer :resource_id
      t.string :resource_type
      t.integer :controlled_attribute_id
      t.integer :controlled_value_id
      t.integer :user_id
    end
  end
end
