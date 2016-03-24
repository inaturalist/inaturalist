class AddIndexToUsersLowercaseLogin < ActiveRecord::Migration
  def up
    execute "CREATE INDEX index_users_on_lower_login ON users (lower(login))"
  end
  def down
    execute "DROP INDEX index_users_on_lower_login"
  end
end
