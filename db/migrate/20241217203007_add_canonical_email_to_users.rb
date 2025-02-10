# frozen_string_literal: true

class AddCanonicalEmailToUsers < ActiveRecord::Migration[6.1]
  def change
    add_column :users, :canonical_email, :string, limit: 100
    add_index :users, :canonical_email
  end
end

