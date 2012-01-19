class CreatePreferences < ActiveRecord::Migration
  def self.up
    create_table :preferences do |t|
      t.string :name, :null => false
      t.references :owner, :polymorphic => true, :null => false
      t.references :group, :polymorphic => true
      t.string :value
      t.timestamps
    end
    add_index :preferences, [:owner_id, :owner_type, :name, :group_id, :group_type], :unique => true, :name => 'index_preferences_on_owner_and_name_and_preference'
  end
  
  def self.down
    drop_table :preferences
  end
end
