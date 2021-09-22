class AddOauthApplicationIdToUsers < ActiveRecord::Migration[4.2]
  def change
    add_column :users, :oauth_application_id, :integer
    add_index :users, :oauth_application_id
  end
end
