class CreateTaxonChangeTaxa < ActiveRecord::Migration
  def self.up
    create_table :taxon_change_taxa do |t|
      t.integer :taxon_change_id
      t.integer :taxon_id
      t.timestamps
    end
  end

  def self.down
    drop_table :taxon_change_taxa
  end
end
