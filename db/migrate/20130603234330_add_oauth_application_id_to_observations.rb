class AddOauthApplicationIdToObservations < ActiveRecord::Migration
  def change
    add_column :observations, :oauth_application_id, :integer
    add_index :observations, :oauth_application_id
  end
end
