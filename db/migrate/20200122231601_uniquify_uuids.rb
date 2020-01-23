class UniquifyUuids < ActiveRecord::Migration
  def up
    change_column :taxa, :uuid, :uuid, default: "uuid_generate_v4()"
    add_index :taxa, :uuid, unique: true
    change_column :users, :uuid, :uuid, default: "uuid_generate_v4()"
    add_index :users, :uuid, unique: true
    change_column :photos, :uuid, :uuid, default: "uuid_generate_v4()"
    add_index :photos, :uuid, unique: true
  end

  def down
    change_column :taxa, :uuid, :uuid, default: nil
    drop_index :taxa, :uuid
    change_column :users, :uuid, :uuid, default: nil
    drop_index :users, :uuid
    change_column :photos, :uuid, :uuid, default: nil
    drop_index :photos, :uuid
  end
end
