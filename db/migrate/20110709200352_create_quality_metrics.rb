class CreateQualityMetrics < ActiveRecord::Migration
  def self.up
    create_table :quality_metrics do |t|
      t.integer :user_id
      t.integer :observation_id
      t.string :metric
      t.boolean :agree, :default => true

      t.timestamps
    end
    add_index :quality_metrics, :user_id
    add_index :quality_metrics, :observation_id
  end

  def self.down
    drop_table :quality_metrics
  end
end
