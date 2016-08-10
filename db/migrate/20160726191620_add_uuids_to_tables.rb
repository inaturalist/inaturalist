class AddUuidsToTables < ActiveRecord::Migration
  def change
    enable_extension "uuid-ossp"
    # add `uuid` columns with default values
    add_column :comments, :uuid, :uuid, default: "uuid_generate_v4()"
    add_column :identifications, :uuid, :uuid, default: "uuid_generate_v4()"
    add_column :observation_field_values, :uuid, :uuid, default: "uuid_generate_v4()"
    add_column :project_observations, :uuid, :uuid, default: "uuid_generate_v4()"
    # index the `uuid` columns
    add_index :comments, :uuid
    add_index :identifications, :uuid
    add_index :observation_field_values, :uuid
    add_index :project_observations, :uuid
  end
end
