class AddSourceIdentifierToTaxon < ActiveRecord::Migration
  def self.up
    add_column :taxa, :conservation_status_source_identifier, :integer
  end

  def self.down
    remove_column :taxa, :conservation_status_source_identifier
  end
end
