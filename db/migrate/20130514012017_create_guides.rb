class CreateGuides < ActiveRecord::Migration
  def change
    create_table :guides do |t|
      t.string :title
      t.text :description
      t.timestamp :published_at
      t.decimal :latitude
      t.decimal :longitude
      t.integer :user_id
      t.integer :place_id

      t.timestamps
    end
    add_index :guides, :user_id
    add_index :guides, :place_id
  end
end
