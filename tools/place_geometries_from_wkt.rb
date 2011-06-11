# Dump all PlaceGeometry geometries to WKT files named by place_id
Place.find_each do |place|
  print "#{place.display_name} (#{place.id}): "
  begin
    open "place_wkts/#{place.id}.wkt" do |wktfile|
      place.save_geom(MultiPolygon.from_ewkt(wktfile.read))
      puts "Saved"
    end
  rescue => e
    puts e.message
  end
  GC.start
end
