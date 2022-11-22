class AddUserIdAndUpdaterIdToTaxonRanges < ActiveRecord::Migration[5.2]
  def up
    add_column :taxon_ranges, :user_id, :integer
    add_column :taxon_ranges, :updater_id, :integer
    add_index :taxon_ranges, :user_id
    add_index :taxon_ranges, :updater_id
  end

  def down
    remove_column :taxon_ranges, :user_id
    remove_column :taxon_ranges, :updater_id
  end
end
