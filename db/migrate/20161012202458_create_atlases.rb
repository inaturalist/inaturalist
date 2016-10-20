class CreateAtlases < ActiveRecord::Migration
  def change
    create_table :atlases do |t|
      t.references :user, index: true
      t.references :taxon, index: true
      t.timestamps null: false
    end
  end
end
