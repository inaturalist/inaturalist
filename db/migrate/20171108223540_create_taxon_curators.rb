class CreateTaxonCurators < ActiveRecord::Migration
  def change
    create_table :taxon_curators do |t|
      t.integer :taxon_id
      t.integer :user_id

      t.timestamps null: false
    end
  end
end
