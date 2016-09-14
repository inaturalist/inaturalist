class AddLatLonAccAdminLevelToUsers < ActiveRecord::Migration
  def change
    add_column :users, :lat_lon_acc_admin_level, :integer
  end
end
