class EmbiggenSourcesUrl < ActiveRecord::Migration
  def up
    change_column :sources, :url, :string, :limit => 512
  end

  def down
    change_column :sources, :url, :string, :limit => 256
  end
end
