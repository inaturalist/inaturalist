class AddSourceToLists < ActiveRecord::Migration
  def self.up
    add_column :lists, :source_id, :integer
    add_column :sources, :user_id, :integer
    add_index :lists, :source_id
    add_index :sources, :user_id
  end

  def self.down
    remove_column :lists, :source_id
    remove_column :sources, :user_id
  end
end
