class CreateGuideTaxa < ActiveRecord::Migration
  def change
    create_table :guide_taxa do |t|
      t.integer :guide_id
      t.integer :taxon_id
      t.string :name
      t.string :display_name

      t.timestamps
    end
    add_index :guide_taxa, :guide_id
    add_index :guide_taxa, :taxon_id
  end
end
