# frozen_string_literal: true

class AddIndicesToAnnouncementImpressions < ActiveRecord::Migration[6.1]
  def change
    add_index :announcement_impressions, [:request_ip, :announcement_id],
      name: "index_announcement_impressions_on_ip_and_id"
    add_index :announcement_impressions, [:user_id, :announcement_id],
      name: "index_announcement_impressions_on_user_id_and_id"
  end
end
