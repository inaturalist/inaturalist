class CreateAtlases < ActiveRecord::Migration
  def change
    create_table :atlases do |t|
      t.references :user
      t.references :taxon
      t.timestamps null: false
    end
  end
end
