class CreateListedTaxonAlterations < ActiveRecord::Migration
  def change
    create_table :listed_taxon_alterations do |t|
      t.references :taxon, index: true
      t.references :user, index: true
      t.references :place, index: true
      t.string :action
      t.timestamps null: false
    end
  end
end
