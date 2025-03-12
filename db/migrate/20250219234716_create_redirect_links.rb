# frozen_string_literal: true

class CreateRedirectLinks < ActiveRecord::Migration[6.1]
  def change
    create_table :redirect_links do | t |
      t.integer :user_id, index: true
      t.string :title
      t.text :description
      t.string :app_store_url
      t.string :play_store_url
      t.integer :view_count, default: 0

      t.timestamps
    end
  end
end
