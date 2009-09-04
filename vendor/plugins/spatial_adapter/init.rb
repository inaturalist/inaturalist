class SpatialAdapterNotCompatibleError < StandardError
end


case ActiveRecord::Base.configurations[RAILS_ENV]['adapter']
when 'mysql'
  require 'mysql_spatial_adapter'
when 'postgresql'
  require 'post_gis_adapter'
else
  raise SpatialAdapterNotCompatibleError.new("Only MySQL and PostgreSQL are currently supported by the spatial adapter plugin.")
end

=begin
# when testing RAILS_ENV isn't set so you'll need to use this style of getting the adapter name
# [TODO] come back and make sure RAILS_ENV exists when running the plugin tests
case ActiveRecord::Base.connection.adapter_name
when 'MySQL'
  require 'mysql_spatial_adapter'
when 'PostgreSQL'
  require 'post_gis_adapter'
 else
  raise SpatialAdapterNotCompatibleError.new("Only MySQL and PostgreSQL are currently supported by the spatial adapter plugin.")
 end
=end
 


