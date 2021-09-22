class AddUuidIndexes < ActiveRecord::Migration
  def up
    change_column :controlled_terms, :uuid, :uuid, default: "uuid_generate_v4()"
    execute "DROP INDEX IF EXISTS index_controlled_terms_on_uuid"
    add_index :controlled_terms, :uuid, unique: true
    change_column :flags, :uuid, :uuid, default: "uuid_generate_v4()"
    execute "DROP INDEX IF EXISTS index_flags_on_uuid"
    add_index :flags, :uuid, unique: true
    change_column :observation_fields, :uuid, :uuid, default: "uuid_generate_v4()"
    execute "DROP INDEX IF EXISTS index_observation_fields_on_uuid"
    add_index :observation_fields, :uuid, unique: true
    change_column :sounds, :uuid, :uuid, default: "uuid_generate_v4()"
    execute "DROP INDEX IF EXISTS index_sounds_on_uuid"
    add_index :sounds, :uuid, unique: true
    change_column :posts, :uuid, :uuid, default: "uuid_generate_v4()"
    execute "DROP INDEX IF EXISTS index_posts_on_uuid"
    add_index :posts, :uuid, unique: true
    change_column :places, :uuid, :uuid, default: "uuid_generate_v4()"
    execute "DROP INDEX IF EXISTS index_places_on_uuid"
    add_index :places, :uuid, unique: true
    change_column :taxa, :uuid, :uuid, default: "uuid_generate_v4()"
    execute "DROP INDEX IF EXISTS index_taxa_on_uuid"
    add_index :taxa, :uuid, unique: true
    change_column :users, :uuid, :uuid, default: "uuid_generate_v4()"
    execute "DROP INDEX IF EXISTS index_users_on_uuid"
    add_index :users, :uuid, unique: true
    change_column :photos, :uuid, :uuid, default: "uuid_generate_v4()"
    execute "DROP INDEX IF EXISTS index_photos_on_uuid"
    add_index :photos, :uuid, unique: true
  end

  def down
    execute "DROP INDEX IF EXISTS index_controlled_terms_on_uuid"
    execute "DROP INDEX IF EXISTS index_flags_on_uuid"
    execute "DROP INDEX IF EXISTS index_observation_fields_on_uuid"
    execute "DROP INDEX IF EXISTS index_sounds_on_uuid"
    execute "DROP INDEX IF EXISTS index_posts_on_uuid"
    execute "DROP INDEX IF EXISTS index_places_on_uuid"
    execute "DROP INDEX IF EXISTS index_taxa_on_uuid"
    execute "DROP INDEX IF EXISTS index_users_on_uuid"
    execute "DROP INDEX IF EXISTS index_photos_on_uuid"
    change_column :controlled_terms, :uuid, :uuid
    change_column :flags, :uuid, :uuid
    change_column :observation_fields, :uuid, :uuid
    change_column :sounds, :uuid, :uuid
    change_column :posts, :uuid, :uuid
    change_column :places, :uuid, :uuid
    change_column :taxa, :uuid, :uuid
    change_column :users, :uuid, :uuid
    change_column :photos, :uuid, :uuid
  end
end
