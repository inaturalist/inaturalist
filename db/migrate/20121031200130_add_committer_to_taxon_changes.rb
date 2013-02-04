class AddCommitterToTaxonChanges < ActiveRecord::Migration
  def change
    add_column :taxon_changes, :committer_id, :integer
    add_index :taxon_changes, :committer_id
  end
end
