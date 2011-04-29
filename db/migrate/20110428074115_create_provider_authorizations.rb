class CreateProviderAuthorizations < ActiveRecord::Migration
  def self.up
    create_table :provider_authorizations do |t|
      t.string  :provider_name, :null => false # e.g. 'facebook' or 'twitter'
      t.text  :provider_uid # e.g. facebook or twitter id. type=text cause openid uids can get pretty long
      t.text  :token # oauth2 token
      t.integer :user_id # inat user id

      t.timestamps
    end
    add_index :provider_authorizations, :user_id
  end

  def self.down
    remove_index :provider_authorizations, :user_id
    drop_table :provider_authorizations
  end
end
