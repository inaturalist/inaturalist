# frozen_string_literal: true

class AlterIdentificationsIndices < ActiveRecord::Migration[6.1]
  def up
    remove_index :identifications, [:observation_id, :created_at]
    add_index :identifications, :observation_id
  end

  def down
    remove_index :identifications, :observation_id
    add_index :identifications, [:observation_id, :created_at]
  end
end
