class CreateAtlasAlterations < ActiveRecord::Migration
  def change
    create_table :atlas_alterations do |t|
      t.references :atlas, index: true
      t.references :user, index: true
      t.references :place, index: true
      t.string :action
      t.timestamps null: false
    end
  end
end
