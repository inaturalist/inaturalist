class CreateTaxonReferences < ActiveRecord::Migration
  def change
    create_table :taxon_references do |t|
      t.text :description
      t.text :relationship, default: 'unknown'
      t.integer :user_id
      t.integer :concept_id
      t.timestamps null: false
    end
  end
end
