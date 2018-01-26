class AddSearchPlaceIdToUsers < ActiveRecord::Migration
  def change
    add_column :users, :search_place_id, :integer
    execute "UPDATE users SET search_place_id = place_id WHERE place_id IS NOT NULL"
  end
end
