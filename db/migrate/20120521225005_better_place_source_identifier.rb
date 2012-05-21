class BetterPlaceSourceIdentifier < ActiveRecord::Migration
  def self.up
    add_column :places, :source_filename, :string
    add_column :place_geometries, :source_filename, :string
    execute <<-SQL
      UPDATE places SET source_filename = source_name;
      UPDATE places SET source_name = source_identifier;
      UPDATE place_geometries SET source_filename = source_name;
      UPDATE place_geometries SET source_name = source_identifier;
    SQL
  end

  def self.down
    execute <<-SQL
      UPDATE places SET source_name = source_filename;
      UPDATE place_geometries SET source_name = source_filename;
    SQL
    remove_column :places, :source_filename
    remove_column :place_geometries, :source_filename
  end
end
