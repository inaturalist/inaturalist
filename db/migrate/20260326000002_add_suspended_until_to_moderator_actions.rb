# frozen_string_literal: true

class AddSuspendedUntilToModeratorActions < ActiveRecord::Migration[6.1]
  def change
    add_column :moderator_actions, :suspended_until, :datetime
    add_column :moderator_actions, :last_edited_by_user_id, :integer
  end
end
