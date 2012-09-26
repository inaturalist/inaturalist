class ConvertRaToDevise < ActiveRecord::Migration
  def up
    #encrypting passwords and authentication related fields
    rename_column :users, "crypted_password", "encrypted_password"
    change_column :users, "encrypted_password", :string, :limit => 128, :default => "", :null => false
    rename_column :users, "salt", "password_salt"
    change_column :users, "password_salt", :string, :default => "", :null => false
    
    #confirmation related fields
    rename_column :users, "activation_code", "confirmation_token"
    rename_column :users, "activated_at", "confirmed_at"
    change_column :users, "confirmation_token", :string
    add_column    :users, "confirmation_sent_at", :datetime

    #reset password related fields
    add_column :users, "reset_password_token", :string
    add_column :users, "reset_password_sent_at", :datetime
    
    #rememberme related fields
    add_column :users, "remember_created_at", :datetime #additional field required for devise.
  end

  def down
    #rememberme related fields
    remove_column :users, :remember_created_at
    
    #reset password related fields
    remove_column :users, :reset_password_token
    remove_column :users, :reset_password_sent_at
    
    #confirmation related fields
    rename_column :users, "confirmation_token", "activation_code"
    rename_column :users, "confirmed_at", "activated_at"
    change_column :users, "activation_code", :string
    remove_column :users, :confirmation_sent_at

    #encrypting passwords and authentication related fields
    rename_column :users, "encrypted_password", "crypted_password"
    change_column :users, "crypted_password", :string, :limit => 40
    rename_column :users, "password_salt", "salt" 
    change_column :users, "salt", :string, :limit => 40
  end
end
