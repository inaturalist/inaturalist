class AddListIndexes < ActiveRecord::Migration
  def self.up
    remove_index :lists, :type
    add_index :lists, [:type, :id]
  end

  def self.down
    add_index :lists, :type
    remove_index :lists, [:type, :id]
  end
end
