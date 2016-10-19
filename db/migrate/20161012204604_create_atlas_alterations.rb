class CreateAtlasAlterations < ActiveRecord::Migration
  def change
    create_table :atlas_alterations do |t|
      t.references :atlas
      t.references :user
      t.references :place
      t.string :action
      t.timestamps null: false
    end
    add_index :atlas_id
    add_index :user_id
    add_index :place_id
  end
end
