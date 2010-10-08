class CreateProjectObservations < ActiveRecord::Migration
  def self.up
    create_table :project_observations do |t|
      t.integer :project_id
      t.integer :observation_id

      t.timestamps
    end
  end

  def self.down
    drop_table :project_observations
  end
end
