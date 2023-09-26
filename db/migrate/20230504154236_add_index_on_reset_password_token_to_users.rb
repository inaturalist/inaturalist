class AddIndexOnResetPasswordTokenToUsers < ActiveRecord::Migration[6.1]
  def change
    add_index :users, [:reset_password_token]
  end
end
