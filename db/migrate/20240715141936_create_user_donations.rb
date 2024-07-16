# frozen_string_literal: true

class CreateUserDonations < ActiveRecord::Migration[6.1]
  def change
    create_table :user_donations do | t |
      t.integer :user_id
      t.datetime :donated_at
      t.timestamps
    end

    add_index :user_donations, :user_id
    add_index :user_donations, :donated_at
  end
end
