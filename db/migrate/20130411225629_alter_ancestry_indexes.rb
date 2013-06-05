class AlterAncestryIndexes < ActiveRecord::Migration
  def up
    remove_index :taxa, :ancestry
    remove_index :places, :ancestry
    execute "CREATE INDEX index_taxa_on_ancestry ON taxa(ancestry text_pattern_ops)"
    execute "CREATE INDEX index_places_on_ancestry ON places(ancestry text_pattern_ops)"
  end

  def down
    execute "DROP INDEX index_taxa_on_ancestry"
    execute "DROP INDEX index_places_on_ancestry"
    add_index :taxa, :ancestry
    add_index :places, :ancestry
  end
end
