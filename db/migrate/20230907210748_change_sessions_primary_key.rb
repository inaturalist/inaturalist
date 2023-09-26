class ChangeSessionsPrimaryKey < ActiveRecord::Migration[6.1]
  def up
    remove_column :sessions, :id
    execute "ALTER TABLE sessions ADD CONSTRAINT sessions_pkey PRIMARY KEY USING INDEX index_sessions_on_session_id"
  end

  def down
    execute "ALTER TABLE sessions DROP CONSTRAINT sessions_pkey"
    execute "ALTER TABLE sessions ADD COLUMN id SERIAL PRIMARY KEY"
    add_index :sessions, :session_id, unique: true
  end
end
