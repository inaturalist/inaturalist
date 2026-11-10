# frozen_string_literal: true

class AddAmbassadorSinceToUsers < ActiveRecord::Migration[6.1]
  def change
    add_column :users, :ambassador_since, :date
  end
end
