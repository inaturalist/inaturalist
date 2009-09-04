class SpatialAdapterNotCompatibleError < StandardError
end


case ActiveRecord::Base.connection.adapter_name
when 'MySQL'
  require 'mysql_spatial_adapter'
when 'PostgreSQL'
  require 'post_gis_adapter'
 else
  raise SpatialAdapterNotCompatibleError.new("Only MySQL and PostgreSQL are currently supported by the spatial adapter plugin.")
 end


