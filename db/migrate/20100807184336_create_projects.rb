class CreateProjects < ActiveRecord::Migration
  def self.up
    create_table :projects do |t|
      t.integer :user_id
      t.string :title
      t.text :description
      t.text :terms
      t.timestamps
    end
  end

  def self.down
    drop_table :projects
  end
end
