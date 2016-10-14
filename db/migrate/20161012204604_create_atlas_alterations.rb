class CreateAtlasAlterations < ActiveRecord::Migration
  def change
    create_table :atlas_alterations do |t|
      t.references :atlas
      t.references :user
      t.references :place
      t.string :action
      t.timestamps null: false
    end
  end
end
