class CreateActivityStreams < ActiveRecord::Migration
  def self.up
    create_table :activity_streams do |t|
      t.integer :user_id
      t.integer :subscriber_id
      t.references :activity_object, :polymorphic => true
      t.timestamps
    end
  end

  def self.down
    drop_table :activity_streams
  end
end
