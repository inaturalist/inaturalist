class RenameSlugNameToSlug < ActiveRecord::Migration
  def up
    if FriendlyId::Slug.column_names.include?('name')
      rename_column :friendly_id_slugs, :name, :slug
    end
  end

  def down
    if FriendlyId::Slug.column_names.include?('slug')
      rename_column :friendly_id_slugs, :slug, :name
    end
  end
end
