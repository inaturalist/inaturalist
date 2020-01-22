class AddUuidColumns < ActiveRecord::Migration
  def change
    # small stuff
    add_column :controlled_terms, :uuid, :uuid, default: "uuid_generate_v4()"
    add_index :controlled_terms, :uuid, unique: true
    add_column :flags, :uuid, :uuid, default: "uuid_generate_v4()"
    add_index :flags, :uuid, unique: true
    add_column :observation_fields, :uuid, :uuid, default: "uuid_generate_v4()"
    add_index :observation_fields, :uuid, unique: true
    add_column :sounds, :uuid, :uuid, default: "uuid_generate_v4()"
    add_index :sounds, :uuid, unique: true
    add_column :places, :uuid, :uuid, default: "uuid_generate_v4()"
    add_index :places, :uuid, unique: true
    add_column :posts, :uuid, :uuid, default: "uuid_generate_v4()"
    add_index :posts, :uuid, unique: true

    # big stuff
    add_column :taxa, :uuid, :uuid
    add_column :users, :uuid, :uuid
    add_column :photos, :uuid, :uuid

    # Run these commands elsewhere to populate the columns in these tables. It
    # will be slow, but it won't hang the site
    # UPDATE taxa SET uuid = uuid_generate_v4() WHERE uuid IS NULL;
    # UPDATE users SET uuid = uuid_generate_v4() WHERE uuid IS NULL;
    # UPDATE photos SET uuid = uuid_generate_v4() WHERE uuid IS NULL;

    # After you've slowly populated the UUID columns for these tables, make a
    # new migration that does this
    # change_column :taxa, :uuid, :uuid, default: "uuid_generate_v4()"
    # add_index :taxa, :uuid, unique: true
    # change_column :users, :uuid, :uuid, default: "uuid_generate_v4()"
    # add_index :users, :uuid, unique: true
    # change_column :photos, :uuid, :uuid, default: "uuid_generate_v4()"
    # add_index :photos, :uuid, unique: true
  end
end
