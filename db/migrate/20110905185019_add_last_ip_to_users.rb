class AddLastIpToUsers < ActiveRecord::Migration
  def self.up
    add_column :users, :last_ip, :string
  end

  def self.down
    remove_column :users, :last_ip
  end
end
