class AddTestGroupsToUsers < ActiveRecord::Migration
  def change
    add_column :users, :test_groups, :string
  end
end
