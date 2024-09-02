# frozen_string_literal: true

class CreateUserInstallations < ActiveRecord::Migration[6.1]
  def change
    create_table :user_installations do | t |
      t.string :installation_id
      t.integer :oauth_application_id
      t.string :platform_id
      t.integer :user_id
      t.date :created_at
      t.date :first_logged_in_at
    end

    add_index :user_installations, :installation_id, unique: true
    add_index :user_installations, :user_id
    add_index :user_installations, [:installation_id, :user_id]
  end
end
