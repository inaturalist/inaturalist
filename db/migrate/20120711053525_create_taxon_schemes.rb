class CreateTaxonSchemes < ActiveRecord::Migration
  def self.up
    create_table :taxon_schemes do |t|
      t.string :title
      t.text :description
      t.integer :source_id
      t.timestamps
    end
  end

  def self.down
    drop_table :taxon_schemes
  end
end
