class AddUuidColumns < ActiveRecord::Migration
  def change
    add_column :controlled_terms, :uuid, :uuid
    add_column :flags, :uuid, :uuid
    add_column :observation_fields, :uuid, :uuid
    add_column :sounds, :uuid, :uuid
    add_column :posts, :uuid, :uuid
    add_column :places, :uuid, :uuid
    add_column :taxa, :uuid, :uuid
    add_column :users, :uuid, :uuid
    add_column :photos, :uuid, :uuid

    # After the columns have been added, you'll want to populate the blank
    # values in Postgres. This will take a long time for large tables in
    # production
    # UPDATE controlled_terms SET uuid = uuid_generate_v4() WHERE uuid IS NULL;
    # UPDATE flags SET uuid = uuid_generate_v4() WHERE uuid IS NULL;
    # UPDATE observation_fields SET uuid = uuid_generate_v4() WHERE uuid IS NULL;
    # UPDATE sounds SET uuid = uuid_generate_v4() WHERE uuid IS NULL;
    # UPDATE posts SET uuid = uuid_generate_v4() WHERE uuid IS NULL;
    # UPDATE places SET uuid = uuid_generate_v4() WHERE uuid IS NULL;
    # UPDATE taxa SET uuid = uuid_generate_v4() WHERE uuid IS NULL;
    # UPDATE users SET uuid = uuid_generate_v4() WHERE uuid IS NULL;
    # UPDATE photos SET uuid = uuid_generate_v4() WHERE uuid IS NULL;

    # When uuid cols have been populated, run another migration like this
    # change_column :controlled_terms, :uuid, :uuid, default: "uuid_generate_v4()"
    # add_index :controlled_terms, :uuid, unique: true
    # change_column :flags, :uuid, :uuid, default: "uuid_generate_v4()"
    # add_index :flags, :uuid, unique: true
    # change_column :observation_fields, :uuid, :uuid, default: "uuid_generate_v4()"
    # add_index :observation_fields, :uuid, unique: true
    # change_column :sounds, :uuid, :uuid, default: "uuid_generate_v4()"
    # add_index :sounds, :uuid, unique: true
    # change_column :posts, :uuid, :uuid, default: "uuid_generate_v4()"
    # add_index :posts, :uuid, unique: true
    # change_column :places, :uuid, :uuid, default: "uuid_generate_v4()"
    # add_index :places, :uuid, unique: true
    # change_column :taxa, :uuid, :uuid, default: "uuid_generate_v4()"
    # add_index :taxa, :uuid, unique: true
    # change_column :users, :uuid, :uuid, default: "uuid_generate_v4()"
    # add_index :users, :uuid, unique: true
    # change_column :photos, :uuid, :uuid, default: "uuid_generate_v4()"
    # add_index :photos, :uuid, unique: true
  end
end
