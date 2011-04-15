class CreateCustomProjects < ActiveRecord::Migration
  def self.up
    create_table :custom_projects do |t|
      t.text :head
      t.text :side
      t.text :css
      t.integer :project_id
      t.timestamps
    end
    add_index :custom_projects, :project_id
  end

  def self.down
    drop_table :custom_projects
  end
end
