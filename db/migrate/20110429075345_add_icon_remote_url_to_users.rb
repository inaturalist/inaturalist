class AddIconRemoteUrlToUsers < ActiveRecord::Migration
  def self.up
    # this will be populated if the user sets their icon via a remote url (e.g. grab user icon from third-party provider)
    add_column :users, :icon_url, :string 
  end

  def self.down
    remove_column :users, :icon_url
  end
end
