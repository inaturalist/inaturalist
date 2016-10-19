class CreateAtlases < ActiveRecord::Migration
  def change
    create_table :atlases do |t|
      t.references :user
      t.references :taxon
      t.timestamps null: false
    end
    add_index :user_id
    add_index :taxon_id
  end
end
