# Dump all PlaceGeometry geometries to WKT files named by place_id
start = ARGV[0] || 1
stop = ARGV[1] || Place.count
Place.find_each(:batch_size => 50, :conditions => ["id BETWEEN ? AND ?", start, stop]) do |place|
  print "#{place.display_name} (#{place.id}): "
  path = "place_wkts/#{place.id}.wkt"
  unless File.exists?(path)
    puts "#{path} doesn't exist, skipping..."
    next
  end
  begin
    wktfile = open(path)
    if wktfile
      place.save_geom(MultiPolygon.from_ewkt(wktfile.read))
      puts "Saved"
    end
  rescue => e
    puts e.message
  ensure
    wktfile.close if wktfile
    wktfile = nil
    place = nil
  end
  GC.start
end
puts "Finshed places #{start} to #{stop}"
