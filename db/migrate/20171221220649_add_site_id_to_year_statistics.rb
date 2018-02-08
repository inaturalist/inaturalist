class AddSiteIdToYearStatistics < ActiveRecord::Migration
  def change
    add_column :year_statistics, :site_id, :integer
    add_index :year_statistics, :site_id
  end
end
