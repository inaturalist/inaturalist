class AddMobileToPhotos < ActiveRecord::Migration
  def self.up
    add_column :photos, :mobile, :boolean, :default => false
  end

  def self.down
    remove_column :photos, :mobile
  end
end
