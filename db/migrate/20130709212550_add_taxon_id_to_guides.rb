class AddTaxonIdToGuides < ActiveRecord::Migration
  def change
  	add_column :guides, :taxon_id, :integer
  	add_index :guides, :taxon_id
  end
end
