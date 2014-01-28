class CreateSites < ActiveRecord::Migration
  def up
    create_table :sites do |t|
      t.string :name
      t.string :url
      t.integer :place_id
      t.integer :source_id
      t.timestamps
    end
    add_index :sites, :place_id
    add_index :sites, :source_id
    add_column :observations, :site_id, :integer
    add_index :observations, :site_id
    add_column :users, :site_id, :integer
    add_index :users, :site_id
  end

  def down
    drop_table :sites
    remove_column :observations, :site_id
    remove_column :users, :site_id
  end
end
