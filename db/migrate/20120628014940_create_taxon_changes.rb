class CreateTaxonChanges < ActiveRecord::Migration
  def self.up
    create_table :taxon_changes do |t|
      t.text :description
      t.integer :taxon_id
      t.integer :source_id
      t.integer :user_id
      t.string :type
      t.timestamps
    end
  end

  def self.down
    drop_table :taxon_changes
  end
end
