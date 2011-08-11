class GoddamnIndexes < ActiveRecord::Migration
  def self.up
    add_index :listed_taxa, :last_observation_id
    add_index :lists, :type
    add_index :places, :check_list_id
  end

  def self.down
    remove_index :listed_taxa, :last_observation_id
    remove_index :lists, :type
    remove_index :places, :check_list_id
  end
end
