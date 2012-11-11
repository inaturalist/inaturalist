class CreateTaxonSchemeTaxa < ActiveRecord::Migration
  def self.up
    create_table :taxon_scheme_taxa do |t|
      t.integer :taxon_scheme_id
      t.integer :taxon_id
      t.timestamps
    end
  end

  def self.down
    drop_table :taxon_scheme_taxa
  end
end
