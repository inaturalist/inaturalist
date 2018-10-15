require "rubygems"
require "optimist"
require "geo_ruby/geojson"

opts = Optimist::options do
    banner <<-EOS
Use manually created clipping polygons to split the parent range of a taxon split into child ranges.
The clipping polygons should be labeled following this convention Pantherophis_alleghaniensis_59644_split.kml
for each child resulting from the split.

Usage:

  rails runner tools/clip_range_for_taxon_split.rb [OPTIONS]

where [options] are:
EOS
  opt :debug, "Print debug statements", :type => :boolean, :short => "-d"
  opt :taxon_split_id, "taxon split id", :type => :string, :short => "-t"
end

start = Time.now

OPTS = opts

unless taxon_split_id = OPTS.taxon_split_id
  puts "You must specify a taxon_split_id"
  exit(0)
end
unless taxon_split = TaxonSplit.where(id: taxon_split_id).first
  puts "can't find that taxon split"
  exit(0)
end

start_taxon = taxon_split.taxon
start_taxon_range = start_taxon.taxon_ranges.first
taxon_split.taxon_change_taxa.each do |end_taxon_change_taxon| #Loop through the end taxa to be created
  end_taxon = end_taxon_change_taxon.taxon
  unless new_range = end_taxon.taxon_ranges.first
    new_range = TaxonRange.new(:taxon_id => end_taxon.id)
  end
  file_name = "#{end_taxon.name} #{end_taxon.id} split.kml".split.join("_")
  puts "Processing #{file_name}..."
  
  #Add a kml to this new amphibian taxon_range
  range_path = "/home/inaturalist/#{file_name}"
  begin
    f = open(range_path, 'r')
    new_range.range = f
    new_range.save
    f.close
    puts "\tAdded a new range for #{end_taxon.name}"
  rescue Errno::ENOENT
    puts "\tFailed to add range: #{range_path} does not exist"
    next
  end
  
  #convert the kml to a geom
  if File.exists?(new_range.range.path)
    tmp_path = File.join(Dir::tmpdir, "#{new_range.id}_#{Time::now.seconds_since_midnight.round}.geojson")
    cmd = "ogr2ogr -f GeoJSON #{tmp_path} #{new_range.range.path}"
    puts "\tRunning #{cmd}"
    begin
      system cmd
      open(tmp_path) do |f|
        if geojsongeom = GeoRuby::SimpleFeatures::Geometry.from_geojson(f.read)
          new_range.geom = geojsongeom.features.first.geometry
          if !new_range.geom.is_a?(MultiPolygon)
            if new_range.geom.is_a?(Polygon)
              new_range.geom = MultiPolygon.from_polygons([new_range.geom])
            else
              puts "\tWeird or empty, break..."
              next
            end
          end
          if new_range.save
            puts "\tSaved"
          else
            puts "\tError: #{new_range.errors.full_messages.to_sentence}"
            next
          end
        else
          puts "\tFailed to parse geojson"
          next
        end
        f.close
      end
      File.delete(tmp_path)
    rescue => e
      puts "\tBailed: #{e}"
    end
  else
    puts "\t #{new_range.range.path} doesn't exist, destroying and skipping"
    next
  end
  
  puts "Checking range..."
  
  range = TaxonRange.select("*, isvalid(geom), st_isvalidreason(geom)").where(id: new_range.id).first
  unless range.st_isvalidreason == 'Valid Geometry'
    begin
      TaxonRange.where(id: new_range.id).update_all("geom = st_buffer(geom,0)")
    rescue
      TaxonRange.where(id: new_range.id).update_all("geom = cleanGeometry(geom)")
    end
  end
  
  puts "Intersecting range..."
  range = TaxonRange.select("*, isvalid(geom), st_isvalidreason(geom)").where(id: new_range.id).first
  if range.st_isvalidreason == 'Valid Geometry'
    raw_intersection = ActiveRecord::Base.connection.select_all(
      "SELECT ST_AsText(ST_Intersection((select geom from taxon_ranges where id = #{new_range.id}), (select geom from taxon_ranges where id = #{start_taxon_range.id})))"
    )[0]["st_astext"]
    raw_intersection = raw_intersection.gsub("POLYGON","MULTIPOLYGON(")+")" unless raw_intersection[0..4] == "MULTI"
    intersection = GeoRuby::SimpleFeatures::MultiPolygon.from_ewkt(raw_intersection)
  end
  
  new_range.destroy
  
  final_range = TaxonRange.new(
    :taxon_id => end_taxon.id,
    :geom => intersection
  )
  
  unless final_range.save
    puts "problem saving range..."
  else
    puts "saved range"
  end
  
  range = TaxonRange.select("*, isvalid(geom), st_isvalidreason(geom)").where(id: final_range.id).first
  puts range.st_isvalidreason
  unless range.st_isvalidreason == 'Valid Geometry'
    puts "fixing new range..."
    begin
      TaxonRange.where(id: final_range.id).update_all("geom = st_buffer(geom,0)")
    rescue
      TaxonRange.where(id: final_range.id).update_all("geom = cleanGeometry(geom)")
    end
  end
  range = TaxonRange.select("*, isvalid(geom), st_isvalidreason(geom)").where(id: final_range.id).first
  puts range.st_isvalidreason
  
  puts "sorting the kml..."
  header = '<?xml version="1.0"?><kml xmlns="http://www.opengis.net/kml/2.2"><Placemark>  <name/>  <description/>  <styleUrl>http://www.inaturalist.org/assets/index.kml#taxon_range</styleUrl>'
  footer = '</Placemark></kml>'
  kml1 = header+final_range.geom.as_kml+footer
  range_path = "/home/inaturalist/taxon_range_#{final_range.id}.kml"
  File.open(range_path, 'w') {|f| f.write(kml1) }
  begin
    f = open(range_path, 'r')
    final_range.range = f
    final_range.save
    f.close
    puts "\tAdded a new range for #{final_range.id}"
  rescue Errno::ENOENT
    puts "\tFailed to add range: #{range_path} does not exist"
  end
end
