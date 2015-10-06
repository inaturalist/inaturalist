class ReplaceSiteHomepageData < ActiveRecord::Migration
  def up
    drop_attached_file :sites, :homepage_data
    add_column :sites, :homepage_data, :text
  end

  def down
    remove_column :sites, :homepage_data
    change_table :sites do |t|
      t.attachment :homepage_data
    end
  end
end
