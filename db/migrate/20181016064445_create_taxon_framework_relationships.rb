class CreateTaxonFrameworkRelationships < ActiveRecord::Migration
  def change
    create_table :taxon_framework_relationships do |t|
      t.text :description
      t.text :relationship, default: 'unknown'
      t.integer :user_id
      t.integer :updater_id
      t.integer :taxon_framework_id
      t.timestamps null: false
    end
  end
end
