class AddAncestryToTaxa < ActiveRecord::Migration
  def self.up
    add_column :taxa, :ancestry, :string
    add_index :taxa, :ancestry
  end

  def self.down
    remove_column :taxa, :ancestry
  end
end
