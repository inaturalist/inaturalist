class CreateTaxonAncestors < ActiveRecord::Migration

  def change
    create_table :taxon_ancestors, id: false do |t|
      t.integer :taxon_id, null: false
      t.integer :ancestor_taxon_id, null: false
    end
    add_index :taxon_ancestors, [ :ancestor_taxon_id, :taxon_id ], unique: true
    add_index :taxon_ancestors, :taxon_id
  end

end
