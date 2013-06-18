class CreateSoundcloudIdentities < ActiveRecord::Migration
  def change
  	create_table :soundcloud_identities do |t|
  		t.string :native_username
  		t.string :native_realname
  		t.integer :user_id
  		t.timestamps
  	end
  end
end
