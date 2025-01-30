# frozen_string_literal: true

class AddPrivateToModeratorActions < ActiveRecord::Migration[6.1]
  def change
    add_column :moderator_actions, :private, :boolean, default: false
  end
end
