class AddZicTimeZoneToObservations < ActiveRecord::Migration
  def up
    add_column :observations, :zic_time_zone, :string
    ActiveSupport::TimeZone::MAPPING.each do |z,zic|
      say "Updating #{z} with #{zic}..."
      execute ActiveRecord::Base.send(:sanitize_sql_array, ["UPDATE observations SET zic_time_zone = ? WHERE time_zone = ?", zic, z])
    end
  end

  def down
    remove_column :observations, :zic_time_zone, :string
  end
end
