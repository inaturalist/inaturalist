class RemoveTaxonColumnFromControlledTerms < ActiveRecord::Migration
  def up
    remove_column :controlled_terms, :valid_within_clade
  end

  def down
    add_column :controlled_terms, :valid_within_clade, :integer
  end
end
