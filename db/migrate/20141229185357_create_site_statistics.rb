class CreateSiteStatistics < ActiveRecord::Migration
  def up
    create_table :site_statistics do |t|
      t.timestamp :created_at
    end
    add_column :site_statistics, :data, :json
  end

  def down
    drop_table :site_statistics
  end
end
