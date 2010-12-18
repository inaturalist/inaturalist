# Simple floats limit the precision of lat/lon columns.  Decimal is the 
# preferred type.  Decent description of the problem at
# http://earthcode.com/blog/2006/12/latitude_and_longitude_columns.html
class ChangeLatLonTypesToDecimal < ActiveRecord::Migration
  def self.up
    execute <<-SQL
      ALTER TABLE `observations` 
        CHANGE `latitude` `latitude` decimal(15,10) DEFAULT NULL,
        CHANGE `longitude` `longitude` decimal(15,10) DEFAULT NULL
    SQL
    execute <<-SQL
      ALTER TABLE `places` 
        CHANGE `latitude` `latitude` decimal(15,10) DEFAULT NULL,
        CHANGE `longitude` `longitude` decimal(15,10) DEFAULT NULL,
        CHANGE `swlat` `swlat` decimal(15,10) DEFAULT NULL,
        CHANGE `swlng` `swlng` decimal(15,10) DEFAULT NULL,
        CHANGE `nelat` `nelat` decimal(15,10) DEFAULT NULL,
        CHANGE `nelng` `nelng` decimal(15,10) DEFAULT NULL
    SQL
  end

  def self.down
    execute <<-SQL
      ALTER TABLE `observations` 
        CHANGE `latitude` `latitude` float DEFAULT NULL,
        CHANGE `longitude` `longitude` float DEFAULT NULL
    SQL
    execute <<-SQL
      ALTER TABLE `places` 
        CHANGE `latitude` `latitude` float DEFAULT NULL,
        CHANGE `longitude` `longitude` float DEFAULT NULL,
        CHANGE `swlat` `swlat` float DEFAULT NULL,
        CHANGE `swlng` `swlng` float DEFAULT NULL,
        CHANGE `nelat` `nelat` float DEFAULT NULL,
        CHANGE `nelng` `nelng` float DEFAULT NULL
    SQL
  end
end
