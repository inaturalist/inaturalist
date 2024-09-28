class AddIndexOnRememberTokenToUsers < ActiveRecord::Migration[6.1]
  def change
    add_index :users, [:remember_token]
  end
end
