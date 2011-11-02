class AddUserToPlaces < ActiveRecord::Migration
  def self.up
    add_column :places, :user_id, :integer
    add_index :places, :user_id
  end

  def self.down
    remove_column :places, :user_id
  end
end
