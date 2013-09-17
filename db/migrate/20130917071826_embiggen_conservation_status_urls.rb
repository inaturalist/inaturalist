class EmbiggenConservationStatusUrls < ActiveRecord::Migration
  def up
    change_column :conservation_statuses, :url, :string, :limit => 512
  end

  def down
    change_column :conservation_statuses, :url, :string, :limit => 256
  end
end
