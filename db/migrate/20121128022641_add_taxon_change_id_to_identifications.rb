class AddTaxonChangeIdToIdentifications < ActiveRecord::Migration
  def change
    add_column :identifications, :taxon_change_id, :integer
    add_index :identifications, :taxon_change_id
  end
end
