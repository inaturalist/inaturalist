class AddFeaturedAtToTaxa < ActiveRecord::Migration
  def self.up
    add_column :taxa, :featured_at, :timestamp
    add_index :taxa, :featured_at
  end

  def self.down
    remove_column :taxa, :featured_at
  end
end
