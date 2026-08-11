# frozen_string_literal: true

class CreateCommentPhotos < ActiveRecord::Migration[6.1]
  def change
    create_table :comment_photos do | t |
      t.integer :user_id, null: false
      t.integer :photo_id, null: false
      # Null until the comment is created and its body is found to reference the
      # photo. A row can sit unlinked for up to CommentPhoto::DRAFT_TTL (a photo
      # dropped into an editor that was never submitted) before it is swept.
      t.integer :comment_id
      t.timestamps
    end

    add_index :comment_photos, :photo_id,
      name: "index_comment_photos_on_photo_id"
    add_index :comment_photos, :comment_id,
      name: "index_comment_photos_on_comment_id"
    # Supports the per-user upload throttle count.
    add_index :comment_photos, [:user_id, :created_at],
      name: "index_comment_photos_on_user_id_and_created_at"
    # Supports the draft sweeper, which only scans unlinked rows.
    add_index :comment_photos, :created_at,
      where: "comment_id IS NULL",
      name: "index_comment_photos_on_created_at_unlinked"
  end
end
