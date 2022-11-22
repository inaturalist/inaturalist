require 'geo_ruby/geojson'
saved = destroyed = errors = 0
TaxonRange.find_each do |tr|
  puts "#{tr.id} (taxon #{tr.taxon_id})"
  
  unless File.exists?(tr.range.path)
    puts "\t #{tr.range.path} doesn't exist, destroying and skipping"
    destroyed += 1
    tr.destroy
    next
  end
  
  tmp_path = "/tmp/#{tr.id}.geojson"
  cmd = "ogr2ogr -f GeoJSON #{tmp_path} #{tr.range.path}"
  puts "\tRunning #{cmd}"
  
  begin
    system cmd
    File.open( tmp_path ) do |f|
      if geojsongeom = Geometry.from_geojson(f.read)
        tr.geom = geojsongeom.features.first.geometry
        if !tr.geom.is_a?(MultiPolygon)
          if tr.geom.is_a?(Polygon)
            tr.geom = MultiPolygon.from_polygons([tr.geom])
          else
            puts "\tWeird or empty, next..."
            destroyed += 1
            tr.destroy
            next
          end
        end
        if tr.save
          saved += 1
          puts "\tSaved"
        else
          errors += 1
          puts "\tError: #{tr.errors.full_messages.to_sentence}"
        end
      else
        errors += 1
        puts "\tFailed to parse geojson"
      end
      f.close
    end
    File.delete(tmp_path)
  rescue => e
    errors += 1
    puts "\tBailed: #{e}"
  end
end

puts "#{saved} saved, #{errors} errors, #{destroyed} destroyed"
