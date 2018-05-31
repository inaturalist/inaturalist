class AddForeignKeyIndicesToAnnotations < ActiveRecord::Migration
  def change
    add_index :annotations, :controlled_attribute_id
    add_index :annotations, :controlled_value_id
    add_index :annotations, :user_id
  end
end
