class CreatePicasaIdentities < ActiveRecord::Migration
  def self.up
    create_table :picasa_identities do |t|
      t.integer :user_id
      t.string :token
      t.datetime :token_created_at
      t.string :picasa_user_id
    
      t.timestamps
    end
    
    add_index :picasa_identities, :user_id
  end

  def self.down
    drop_table :picasa_identities
  end
end
