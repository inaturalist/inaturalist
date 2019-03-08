class AddIndexToTagsLowerName < ActiveRecord::Migration
  def up
    execute "CREATE INDEX index_tags_on_lower_name ON tags ((lower(name)::text))"
  end
  def down
    execute "DROP INDEX index_tags_on_lower_name"
  end
end
