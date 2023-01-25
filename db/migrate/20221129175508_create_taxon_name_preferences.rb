class CreateTaxonNamePreferences < ActiveRecord::Migration[6.1]
  def change
    create_table :taxon_name_preferences, id: false do |t|
      t.integer :id, primary_key: true
      t.integer :position, limit: 2
      t.integer :user_id, index: true, null: false
      t.integer :place_id
      t.string :lexicon
      t.timestamps
    end
  end
end
