class CreateDeletedObservations < ActiveRecord::Migration
  def change
    create_table :deleted_observations do |t|
      t.integer :user_id
      t.integer :observation_id
      t.timestamps
    end
    add_index :deleted_observations, [:user_id, :created_at]
  end
end
