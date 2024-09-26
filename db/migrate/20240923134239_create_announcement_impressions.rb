# frozen_string_literal: true

class CreateAnnouncementImpressions < ActiveRecord::Migration[6.1]
  def change
    create_table :announcement_impressions do | t |
      t.integer :announcement_id
      t.integer :user_id
      t.string :request_ip
      t.string :platform_type
      t.integer :impressions_count, default: 0
      t.timestamps
    end

    add_index :announcement_impressions, :announcement_id
    add_index :announcement_impressions, :user_id
  end
end
