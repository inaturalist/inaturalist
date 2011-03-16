class AddDeltaToPlaces < ActiveRecord::Migration
  def self.up
    add_column :places, "delta", :boolean, :default => false
  end

  def self.down
    remove_column :places, "delta"
  end
end
