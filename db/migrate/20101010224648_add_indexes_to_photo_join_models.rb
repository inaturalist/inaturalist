class AddIndexesToPhotoJoinModels < ActiveRecord::Migration
  def self.up
    add_index :taxon_photos, :taxon_id
    add_index :taxon_photos, :photo_id
    add_index :observation_photos, :observation_id
    add_index :observation_photos, :photo_id
  end

  def self.down
    remove_index :taxon_photos, :taxon_id
    remove_index :taxon_photos, :photo_id
    remove_index :observation_photos, :observation_id
    remove_index :observation_photos, :photo_id
  end
end
