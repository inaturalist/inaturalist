# frozen_string_literal: true

class CreateAnnouncementDismissals < ActiveRecord::Migration[6.1]
  def change
    create_table :announcement_dismissals do | t |
      t.integer :announcement_id
      t.integer :user_id
      t.timestamps
    end

    add_index :announcement_dismissals, :announcement_id
    add_index :announcement_dismissals, :user_id
  end
end
