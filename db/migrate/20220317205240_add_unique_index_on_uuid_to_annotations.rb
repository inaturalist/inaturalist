class AddUniqueIndexOnUuidToAnnotations < ActiveRecord::Migration[6.1]
  def change
    add_index :annotations, :uuid, unique: true
  end
end
