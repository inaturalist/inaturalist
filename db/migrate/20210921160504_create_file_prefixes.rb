class CreateFilePrefixes < ActiveRecord::Migration[5.2]
  def change
    create_table :file_prefixes, id: false do |t|
      t.integer :id, limit: 2, primary_key: true
      t.string :prefix, null: false
      t.timestamps
    end
    add_index :file_prefixes, :prefix
  end
end
