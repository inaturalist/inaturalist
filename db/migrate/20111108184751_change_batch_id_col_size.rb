class ChangeBatchIdColSize < ActiveRecord::Migration
  def self.up
    change_column :activity_streams, :batch_ids, :string, :limit => 512
  end

  def self.down
    change_column :activity_streams, :batch_ids, :string, :limit => 255
  end
end
