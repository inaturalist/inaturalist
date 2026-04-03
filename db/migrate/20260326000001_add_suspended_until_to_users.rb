# frozen_string_literal: true

class AddSuspendedUntilToUsers < ActiveRecord::Migration[6.1]
  def change
    add_column :users, :suspended_until, :datetime
  end
end
