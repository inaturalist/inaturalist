class AddBatchIdsAndIndexesToActivityStreams < ActiveRecord::Migration
  def self.up
    add_column :activity_streams, :batch_ids, :string
    add_index :activity_streams, [:user_id, :activity_object_type]
    add_index :activity_streams, :subscriber_id
  end

  def self.down
    remove_column :activity_streams, :batch_ids, :string
    remove_index :activity_streams, [:user_id, :activity_object_type]
    remove_index :activity_streams, :subscriber_id
  end
end
