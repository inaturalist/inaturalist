class RemoveUnusedTaxaColumns < ActiveRecord::Migration[6.1]
  def up
    remove_column :taxa, :complete
    remove_column :taxa, :complete_rank
    remove_column :taxa, :conservation_status
    remove_column :taxa, :conservation_status_source_id
    remove_column :taxa, :conservation_status_source_identifier
  end

  def down
    add_column :taxa, :complete, :boolean
    add_column :taxa, :complete_rank, :string
    add_column :taxa, :conservation_status, :integer
    add_column :taxa, :conservation_status_source_id, :integer
    add_column :taxa, :conservation_status_source_identifier, :integer
  end
end
