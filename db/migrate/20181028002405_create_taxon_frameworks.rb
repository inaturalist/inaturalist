class CreateTaxonFrameworks < ActiveRecord::Migration
  def change
    create_table :taxon_frameworks do |t|
      t.integer :taxon_id
      t.text :description
      t.integer :rank_level
      t.boolean :complete, :default => false
      t.integer :source_id
      t.integer :user_id
      t.integer :updater_id
      t.timestamps
    end
  end
end
