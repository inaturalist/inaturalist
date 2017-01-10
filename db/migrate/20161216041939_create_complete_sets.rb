class CreateCompleteSets < ActiveRecord::Migration
  def change
    create_table :complete_sets do |t|
      t.references :user, index: true
      t.references :taxon, index: true
      t.references :place, index: true
      t.text :description
      t.integer :source_id
      t.timestamps null: false
    end
  end
end
