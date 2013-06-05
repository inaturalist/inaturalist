class AddFieldsToOauthApplications < ActiveRecord::Migration
  def up
    add_attachment :oauth_applications, :image
    add_column :oauth_applications, :url, :string
    add_column :oauth_applications, :description, :text
  end

  def down
    remove_attachment :oauth_applications, :image
    remove_column :oauth_applications, :url
    remove_column :oauth_applications, :description
  end
end
