class AddStateIndexToUsers < ActiveRecord::Migration
  def self.up
    add_index :users, :state
  end

  def self.down
    remove_index :users, :state
  end
end
