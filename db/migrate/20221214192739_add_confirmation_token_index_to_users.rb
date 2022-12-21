# frozen_string_literal: true

class AddConfirmationTokenIndexToUsers < ActiveRecord::Migration[6.1]
  def change
    add_index :users, :confirmation_token
  end
end
