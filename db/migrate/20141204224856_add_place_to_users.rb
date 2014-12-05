class AddPlaceToUsers < ActiveRecord::Migration
  def change
    add_column :users, :place_id, :integer
    add_index :users, :place_id
  end
end
