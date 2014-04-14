class AddTaxonNameIdToTaxonSchemeTaxon < ActiveRecord::Migration
  def up
    add_column :taxon_scheme_taxa, :taxon_name_id, :integer
    add_index :taxon_scheme_taxa, :taxon_name_id
    batch_size = 500
    ((TaxonSchemeTaxon.maximum(:id) || 0) / batch_size).times do |i|
      start = i * batch_size
      stop  = i * batch_size + batch_size - 1
      sql = <<-SQL
        UPDATE taxon_scheme_taxa
        SET taxon_name_id = taxon_names.id
        FROM 
          taxon_names
        WHERE 
          taxon_names.taxon_id = taxon_scheme_taxa.taxon_id
          AND taxon_names.is_valid = 't'
          AND taxon_names.lexicon = 'Scientific Names'
          AND taxon_scheme_taxa.id BETWEEN #{start} AND #{stop}
      SQL
      execute sql.gsub(/\s+/m, ' ')
    end
  end
  
  def down
    remove_column :taxon_scheme_taxa, :taxon_name_id
  end
end
