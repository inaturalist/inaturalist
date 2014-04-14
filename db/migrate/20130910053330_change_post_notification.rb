class ChangePostNotification < ActiveRecord::Migration
  def up
    Update.update_all("notification = 'created_post'", "notification = 'created_project_post'")
  end

  def down
    Update.update_all("notification = 'created_project_post'", "notification = 'created_post' AND resource_type = 'Project'")
  end
end
