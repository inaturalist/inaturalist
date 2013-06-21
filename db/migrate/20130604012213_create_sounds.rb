class CreateSounds < ActiveRecord::Migration
  def change
  	create_table :sounds do |t|
  		t.integer :user_id
  		t.string :native_username
  		t.string :native_realname
  		t.string :native_sound_id
  		t.string :native_page_url
  		t.integer :license
  		t.string :type
  		t.string :sound_url
  		t.timestamps
  	end

  	create_table :observations_sounds do |t|
  		t.integer :observation_id
  		t.integer :sound_id
  	end
  	add_index :sounds, :user_id
  	add_index :sounds, :type
  	add_index :observations_sounds, :observation_id
    add_index :observations_sounds, :sound_id
  end
end
