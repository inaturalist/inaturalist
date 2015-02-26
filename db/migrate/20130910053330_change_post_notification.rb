class ChangePostNotification < ActiveRecord::Migration
  def up
    Update.where(notification: "created_project_post").update_all(notification: "created_post")
  end

  def down
    Update.where(notification: "created_post", resource_type: "Project").
      update_all(notification: "created_project_post")
  end
end
