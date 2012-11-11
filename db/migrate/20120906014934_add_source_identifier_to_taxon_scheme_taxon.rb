class AddSourceIdentifierToTaxonSchemeTaxon < ActiveRecord::Migration
  def self.up
    add_column :taxon_scheme_taxa, :source_identifier, :string
  end

  def self.down
    remove_column :taxon_scheme_taxa, :source_identifier
  end
end
