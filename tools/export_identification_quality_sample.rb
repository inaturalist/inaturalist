OPTS = Optimist::options do
    banner <<-EOS

Generates a random sample of all verifiable iNaturalist observations and stores data on them in a JSON file

Usage:

  rails runner tools/export_identification_quality_sample.rb
  rails runner tools/export_identification_quality_sample.rb --sample-size 10000

where [options] are:
EOS
  opt :debug, "Print debug statements", type: :boolean, short: "-d"
  opt :file, "Where to write output. Default will be tmp path.", :type => :string, :short => "-f"
  opt :sample_size, "Number of observations to sample", type: :int, short: "-s", default: 100
end

start = Time.now

puts "getting denominator" if OPTS.debug
denom = Observation.where( "quality_grade IN ( ? )", ["research","needs_id"] ).count

puts "sampling observations" if OPTS.debug
num = OPTS.sample_size
percent = ( num + num * 0.2 ) / denom.to_f * 100
sql_query = <<-SQL
  SELECT o.id FROM observations o TABLESAMPLE bernoulli( #{percent} )
  WHERE quality_grade IN ( 'research', 'needs_id' )
SQL
res = ActiveRecord::Base.connection.execute( sql_query )
obs_ids = res.map{ |a| a["id"].to_i }.shuffle[ 0..( num - 1 ) ]

puts "storing sample in array" if OPTS.debug
data = []
Observation.includes( :identifications ).where( id: obs_ids ).each do |o|
  involved_taxa = Taxon.where( id: [ o.taxon_id, o.community_taxon_id, o.identifications.map{ |a| a.taxon_id } ].flatten.uniq )
  all_ancestries = involved_taxa.map{ |a| a.ancestry.nil? ? a.id.to_s : a.ancestry + "/#{a.id}" }
  matching_taxon = involved_taxa.select{|a| a[:id]==o.taxon_id}.first
  ancestor_ids = matching_taxon.nil? ? [o.taxon_id] : [matching_taxon.ancestor_ids,o.taxon_id].flatten

  identifications = o.identifications.
    sort_by{|i| i.created_at}.
    map{|i|
      {
        taxon_id: i.taxon_id,
        created_at: i.created_at,
        current: i.current,
        disagreement: i.disagreement,
        previous_observation_taxon_id: i.previous_observation_taxon_id,
        user_id: i.user_id
      }
    }

  data << {
    observation_id: o.id,
    taxon_id: o.taxon_id,
    ancestry: ancestor_ids,
    iconic_taxon_id: o.iconic_taxon_id, 
    quality: o.quality_grade,
    community_taxon_id: o.community_taxon_id,
    identifications: identifications,
    all_ancestries: all_ancestries,
    geoprivacy: o.geoprivacy,
    latitude: o.latitude,
    longitude: o.longitude,
    positional_accuracy: o.public_positional_accuracy,
    created_at: o.created_at,
    year: o.created_at.year
  }  
end

puts "add states, countries and continents" if OPTS.debug

obs_place_ids = []
i=0
data.map{|a| a[:observation_id]}.each_slice(500) do | obs_ids |
  dat = INatAPIService.observations( { id: obs_ids } )
  obs_place_ids << dat["results"].map{|a| {id: a["id"], place_id: a["place_ids"]}}
  i+=1
end
obs_place_ids = obs_place_ids.flatten; nil

continents = Place.where(admin_level: -1).pluck(:id)
countries = Place.where(admin_level: 0).pluck(:id)
states = Place.where(admin_level: 1).pluck(:id)
obs_place_ids.each do |row|
  continent = row[:place_id] & continents
  country = row[:place_id] & countries
  state = row[:place_id] & states
  out_row = data.select{|i| i[:observation_id] == row[:id]}.first
  out_row[:country] = ( country.count == 0 ? nil : country.first )
  out_row[:continent] = ( continent.count == 0 ? nil : continent.first )
  out_row[:state] = ( state.count == 0 ? nil : state.first )
end

puts "saving JSON data" if OPTS.debug

work_path = Dir.mktmpdir
FileUtils.mkdir_p work_path, :mode => 0755
basename = "export-observation-sample-#{Date.today.to_s.gsub(/\-/, '')}-#{Time.now.to_i}"
out_path = OPTS.file || File.join( work_path, "#{basename}.json" )

File.open( out_path, "w" ) do |f|
  f.write( data.to_json )
end

puts 
puts "Wrote #{data.count} observations in #{Time.now - start}s"
puts "Wrote #{out_path}"
puts

