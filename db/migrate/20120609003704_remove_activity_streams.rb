class RemoveActivityStreams < ActiveRecord::Migration
  def self.up
    drop_table :activity_streams
  end

  def self.down
    create_table :activity_streams do |t|
      t.integer :user_id
      t.integer :subscriber_id
      t.references :activity_object, :polymorphic => true
      t.timestamps
    end
  end
end
