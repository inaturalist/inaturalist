class UpdateListedTaxa < ActiveRecord::Migration
  def self.up
    add_column :listed_taxa, :description, :text
    add_column :listed_taxa, :comments_count, :integer, :default => 0
    add_column :listed_taxa, :user_id, :integer
    add_column :listed_taxa, :updater_id, :integer
    
    add_index :listed_taxa, :user_id
  end

  def self.down
    remove_column :listed_taxa, :description
    remove_column :listed_taxa, :comments_count
    remove_column :listed_taxa, :user_id
    add_column :listed_taxa, :updater_id, :integer
  end
end
