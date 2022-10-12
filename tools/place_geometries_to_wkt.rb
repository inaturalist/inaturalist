FileUtils.mkdir_p "place_wkts"
PlaceGeometry.find_each do |place_geometry|
  print "Working on #{place_geometry.id} (place #{place_geometry.place_id})... "
  path = "place_wkts/#{place_geometry.place_id}.wkt"
  File.open( path, "w" ) do |f|
    f.write place_geometry.geom.as_wkt
    puts path
  end
end
