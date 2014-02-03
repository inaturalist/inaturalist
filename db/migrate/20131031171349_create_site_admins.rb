class CreateSiteAdmins < ActiveRecord::Migration
  def up
    create_table :site_admins do |t|
      t.integer :user_id
      t.integer :site_id
      t.timestamps
    end
    add_index :site_admins, :user_id
    add_index :site_admins, :site_id
  end

  def down
    drop_table :site_admins
  end
end
