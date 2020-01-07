class AddIndexToUsersEmail < ActiveRecord::Migration
  def up
    add_index :users, :email
    execute "CREATE INDEX index_users_on_lower_email ON users (lower(email))"
  end
  def down
    execute "DROP INDEX index_users_on_lower_email"
    remove_index :users, :email
  end
end
