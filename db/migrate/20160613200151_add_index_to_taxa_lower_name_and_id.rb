class AddIndexToTaxaLowerNameAndId < ActiveRecord::Migration
  def up
    execute "CREATE INDEX index_taxa_on_lower_name_and_id ON taxa ((lower(name)::text), id)"
  end
  def down
    execute "DROP INDEX index_taxa_on_lower_name_and_id"
  end
end
