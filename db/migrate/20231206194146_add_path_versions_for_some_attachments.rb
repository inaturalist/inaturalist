# frozen_string_literal: true

class AddPathVersionsForSomeAttachments < ActiveRecord::Migration[6.1]
  def change
    add_column :year_statistic_localized_shareable_images, :shareable_image_path_version,
      :smallint, null: false, default: 0
    add_column :users, :icon_path_version, :smallint, null: false, default: 0
    add_column :projects, :icon_path_version, :smallint, null: false, default: 0
    add_column :projects, :cover_path_version, :smallint, null: false, default: 0
  end
end
