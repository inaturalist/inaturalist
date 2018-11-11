class CreateExternalTaxa < ActiveRecord::Migration
  def change
    create_table :external_taxa do |t|
      t.string :name
      t.string :rank
      t.string :parent_name
      t.string :parent_rank
      t.string :url
      t.integer :taxon_framework_relationship_id
      t.timestamps null: false
    end
  end
end
