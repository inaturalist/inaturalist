class AddSomeMoreIndexes < ActiveRecord::Migration
  def self.up
    add_index :taxon_ranges, :taxon_id
    add_index :places, :place_type
  end

  def self.down
    remove_index :taxon_ranges, :taxon_id
    remove_index :places, :place_type
  end
end
