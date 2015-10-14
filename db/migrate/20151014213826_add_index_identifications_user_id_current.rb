class AddIndexIdentificationsUserIdCurrent < ActiveRecord::Migration
  def change
    add_index :identifications, [ :user_id, :current ]
  end
end
