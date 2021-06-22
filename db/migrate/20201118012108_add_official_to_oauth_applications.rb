class AddOfficialToOauthApplications < ActiveRecord::Migration
  def change
    add_column :oauth_applications, :official, :boolean, default: false
  end
end
