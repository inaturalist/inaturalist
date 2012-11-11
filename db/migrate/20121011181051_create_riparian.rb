class CreateRiparian < ActiveRecord::Migration
  def self.up
    create_table :flow_tasks do |t|
      t.string :type
      t.string :options
      t.string :command
      t.string :error
      t.datetime :started_at
      t.datetime :finished_at
      t.integer :user_id
      t.string :redirect_url
      t.timestamps
    end
    add_index :flow_tasks, :user_id
    
    create_table :flow_task_resources do |t|
      t.integer :flow_task_id
      t.string :resource_type
      t.integer :resource_id
      t.string :type
      t.string :file_file_name
      t.string :file_content_type
      t.integer :file_file_size
      t.datetime :file_updated_at
      t.text :extra
      t.timestamps
    end
    add_index :flow_task_resources, [:flow_task_id, :type]
    add_index :flow_task_resources, [:resource_type, :resource_id]
    
  end

  def self.down
    drop_table :flow_tasks
    drop_table :flow_task_resources
  end
end