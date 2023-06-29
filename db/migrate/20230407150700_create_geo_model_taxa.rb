class CreateGeoModelTaxa < ActiveRecord::Migration[6.1]
  def change
    create_table :geo_model_taxa do |t|
      t.integer :taxon_id
      t.float :prauc
      t.float :precision
      t.float :recall
      t.float :f1
      t.float :threshold
      t.timestamps
    end
    add_index :geo_model_taxa, :taxon_id
  end
end
