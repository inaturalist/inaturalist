# frozen_string_literal: true

class AddSentAtToMessages < ActiveRecord::Migration[6.1]
  def change
    add_column :messages, :sent_at, :timestamp
  end
end
