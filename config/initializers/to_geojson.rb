class Array
  def to_geojson(options = {})
    return to_json unless first.is_a?(ActiveRecord::Base)
    klass = first.class
    geomcol = first.class.columns.detect{|c| c.is_a?(SpatialAdapter::SpatialColumn)}
    return to_json unless geomcol
    data = {:type => "FeatureCollection"}
    # only = options[:only] ? options[:only].map(&:to_s) : []
    # methods = options[:methods] ? options[:methods].map(&:to_s) : []
    # properties = ((klass.column_names || only) - [geomcol.name] + methods)
    data[:features] = map do |item|
      {
        :geometry => item.send(geomcol.name),
        # :properties => properties.map{|p| {p => item.send(p)}}
        :properties => item
      }
    end
    data.to_json(options)
  end
end
