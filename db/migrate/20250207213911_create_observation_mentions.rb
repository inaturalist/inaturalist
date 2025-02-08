# frozen_string_literal: true

class CreateObservationMentions < ActiveRecord::Migration[6.1]
  def change
    create_table :observation_mentions do | t |
      t.integer :observation_id
      t.string :sender_type
      t.integer :sender_id
      t.integer :user_id
      t.timestamps
    end
    add_index :observation_mentions, :observation_id
    add_index :observation_mentions, [:sender_type, :sender_id]
  end
end
