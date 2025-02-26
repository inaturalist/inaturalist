# frozen_string_literal: true

class AddIndexOnPhotoIdToDeletedPhotos < ActiveRecord::Migration[6.1]
  def change
    add_index :deleted_photos, :photo_id
  end
end
