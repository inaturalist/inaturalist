class AdjustTaxonNameIndex < ActiveRecord::Migration
  def up
    remove_index :taxon_names, :name
    # add_index :taxon_names, 'lower(name)', :name => "taxon_names_lower_name_index"
    execute <<-SQL
      CREATE INDEX taxon_names_lower_name_index ON taxon_names ((lower(name)));
    SQL
  end

  def down
    remove_index :taxon_names, :name => "taxon_names_lower_name_index"
    add_index :taxon_names, :name
  end
end
