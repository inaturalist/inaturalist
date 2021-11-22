class CreateFileExtensions < ActiveRecord::Migration[5.2]
  def change
    create_table :file_extensions, id: false do |t|
      t.integer :id, limit: 2, primary_key: true
      t.string :extension, null: false
      t.timestamps
    end
    add_index :file_extensions, :extension
  end
end
