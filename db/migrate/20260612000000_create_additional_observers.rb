# frozen_string_literal: true

class CreateAdditionalObservers < ActiveRecord::Migration[6.1]
  def up
    create_table :additional_observers do | t |
      t.integer :observation_id, null: false
      t.integer :user_id, null: false
      t.integer :added_by_user_id, null: false
      t.timestamps
    end

    add_index :additional_observers, [:observation_id, :user_id], unique: true
    add_index :additional_observers, :user_id
  end

  def down
    drop_table :additional_observers
  end
end
