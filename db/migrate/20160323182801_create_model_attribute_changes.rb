class CreateModelAttributeChanges < ActiveRecord::Migration
  def change
    create_table :model_attribute_changes do |t|
      t.string :model_type
      t.integer :model_id
      t.string :field_name
      t.datetime :changed_at
    end
    add_index :model_attribute_changes, [ :model_id, :field_name ]
    add_index :model_attribute_changes, :changed_at
  end
end
