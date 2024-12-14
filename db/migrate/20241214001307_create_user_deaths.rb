# frozen_string_literal: true

class CreateUserDeaths < ActiveRecord::Migration[6.1]
  def change
    create_table :user_deaths do | t |
      t.integer :user_id
      t.date :died_on
      t.string :obituary_url
      t.string :tributes_url
      t.integer :updater_id

      t.timestamps
    end
    add_index :user_deaths, :user_id
    add_index :user_deaths, :updater_id
  end
end
