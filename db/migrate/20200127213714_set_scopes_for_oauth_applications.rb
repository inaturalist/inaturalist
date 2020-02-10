class SetScopesForOauthApplications < ActiveRecord::Migration
  def up
    execute "UPDATE oauth_applications SET scopes = 'login write'"
  end

  def down
    execute "UPDATE oauth_applications SET scopes = null" 
  end
end
