class RenameSlugs < ActiveRecord::Migration
  def up
    rename_table :slugs, :friendly_id_slugs
    rename_column :projects, :cached_slug, :slug
  end

  def down
    rename_table :friendly_id_slugs, :slugs
    rename_column :projects, :slug, :cached_slug
  end
end
