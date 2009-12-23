class ChangeFlickrPhotosToPhotos < ActiveRecord::Migration
  def self.up
    drop_table :photos if table_exists?(:photos)
    rename_table :flickr_photos, :photos
    rename_column :photos, :flickr_native_photo_id, :native_photo_id
    rename_column :photos, :flickr_page_url,        :native_page_url
    rename_column :photos, :flickr_username,        :native_username
    rename_column :photos, :flickr_realname,        :native_realname
    rename_column :photos, :flickr_license,         :license
    add_column :photos, :type, :string
    execute <<-SQL
      UPDATE photos SET type = 'FlickrPhoto'
    SQL
    
    # Ditch old HABTM tables
    create_table :observation_photos do |t|
      t.integer :observation_id, :null => false
      t.integer :photo_id, :null => false
      t.integer :position
    end
    execute <<-SQL
      INSERT INTO observation_photos (observation_id, photo_id) 
        SELECT observation_id, flickr_photo_id FROM flickr_photos_observations
    SQL
    drop_table :flickr_photos_observations
    
    create_table :taxon_photos do |t|
      t.integer :taxon_id, :null => false
      t.integer :photo_id, :null => false
      t.integer :position
    end
    execute <<-SQL
      INSERT INTO taxon_photos (taxon_id, photo_id)
        SELECT taxon_id, flickr_photo_id FROM flickr_photos_taxa
    SQL
    drop_table :flickr_photos_taxa
  end

  def self.down
    rename_table :photos, :flickr_photos
    rename_column :flickr_photos, :native_photo_id, :flickr_native_photo_id
    rename_column :flickr_photos, :native_page_url, :flickr_page_url
    rename_column :flickr_photos, :native_username, :flickr_username
    rename_column :flickr_photos, :native_realname, :flickr_realname
    rename_column :flickr_photos, :license,         :flickr_license
    remove_column :flickr_photos, :type
    
    # Resurrect old HABTM tables
    rename_table :observation_photos, :flickr_photos_observations
    rename_table :taxon_photos, :flickr_photos_taxa
    remove_column :flickr_photos_observations, :id
    remove_column :flickr_photos_taxa, :id
    rename_column :flickr_photos_observations, :photo_id, :flickr_photo_id
    rename_column :flickr_photos_taxa, :photo_id, :flickr_photo_id
  end
end
