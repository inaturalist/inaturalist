# frozen_string_literal: true

class CreateUserVirtuousTags < ActiveRecord::Migration[6.1]
  def change
    create_table :user_virtuous_tags do | t |
      t.integer :user_id
      t.string :virtuous_tag
      t.timestamps
    end

    add_index :user_virtuous_tags, [:user_id, :virtuous_tag], unique: true
    add_index :user_virtuous_tags, :virtuous_tag
  end
end
