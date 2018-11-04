class CreateConcepts < ActiveRecord::Migration
  def change
    create_table :concepts do |t|
      t.integer :taxon_id
      t.text :description
      t.integer :rank_level
      t.boolean :complete, :default => false
      t.integer :source_id
      t.integer :user_id
      t.timestamps
    end
  end
end
