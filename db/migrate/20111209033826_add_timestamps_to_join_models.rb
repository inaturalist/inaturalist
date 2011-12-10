class AddTimestampsToJoinModels < ActiveRecord::Migration
  def self.up
    add_column :observation_photos, :created_at, :datetime
    add_column :observation_photos, :updated_at, :datetime
    add_column :taxon_photos, :created_at, :datetime
    add_column :taxon_photos, :updated_at, :datetime
  end

  def self.down
    remove_column :observation_photos, :created_at
    remove_column :observation_photos, :updated_at
    remove_column :taxon_photos, :created_at
    remove_column :taxon_photos, :updated_at
  end
end
