class CreateTaxonDescriptions < ActiveRecord::Migration
  def change
    create_table :taxon_descriptions do |t|
      t.integer :taxon_id
      t.string :locale
      t.text :body
    end
    add_index :taxon_descriptions, :taxon_id
  end
end
