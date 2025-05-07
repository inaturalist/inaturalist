# frozen_string_literal: true

class CreateProjectFaves < ActiveRecord::Migration[6.1]
  def change
    create_table :project_faves do | t |
      t.integer :project_id
      t.integer :user_id
      t.integer :position

      t.timestamps
    end
    add_index :project_faves, :project_id
    add_index :project_faves, :user_id
  end
end
