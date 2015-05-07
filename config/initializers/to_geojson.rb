class Array
  def to_geojson(options = {})
    return to_json unless first.is_a?(ActiveRecord::Base)
    klass = first.class
    geomcol = first.class.columns.detect{ |c|
      c.is_a?(ActiveRecord::ConnectionAdapters::PostGISAdapter::SpatialColumn) }
    return to_json unless geomcol
    data = {:type => "FeatureCollection"}
    data[:features] = map do |item|
      {
        :geometry => item.send(geomcol.name),
        :properties => item
      }
    end
    data.to_json(options)
  end
end

# Override the as_json method in all Geometry sublcasses to output a hash, not a json string
GeoRuby::SimpleFeatures::Geometry.subclasses.each do |klass|
  klass.class_eval do
    define_method(:as_json) do |*args|
      options = args.first || {}
      {:type => self.class.to_s.split('::').last, :coordinates => self.to_coordinates}.as_json(options)
    end
  end
end
