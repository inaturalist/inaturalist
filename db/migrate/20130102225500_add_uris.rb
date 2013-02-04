# Will be used to separate content from different sites running from the same database.
# In the future we might use them to support content from completely different sources.
class AddUris < ActiveRecord::Migration
  def up
    add_column :observations, :uri, :string
    add_column :users, :uri, :string
    add_index :observations, :uri
    add_index :users, :uri
    Observation.update_all(["uri = ? || id", "#{FakeView.observations_url}/"])
    User.update_all(["uri = ? || id", "#{FakeView.users_url}/"])
  end

  def down
    remove_column :observations, :uri
    remove_column :users, :uri
  end
end
