class AddLockedToTaxa < ActiveRecord::Migration
  def self.up
    add_column :taxa, :locked, :boolean, :default => false, :null => false
    add_index :taxa, :locked
  end

  def self.down
    remove_column :taxa, :locked
  end
end
