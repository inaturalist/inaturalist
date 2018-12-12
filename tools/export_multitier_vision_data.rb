directory = "/home/inaturalist"
test_count = 30
val_percent = 0.1
val_thres = 10
root_id = 48460

# Pick the root of some branch to export
root = Taxon.find( root_id )
ancestry_string = root.rank_level == Taxon::ROOT_LEVEL ?
  "#{ root.id }" : "#{ root.ancestry }/#{ root.id }"

# Part 1: determine the taxonomy

# Create a hash of the obs photo count for each node descending from the root
sql_query = <<-SQL
  SELECT t.id AS taxa_id, COUNT(*)
  FROM observations o
  JOIN taxa t ON t.id = o.taxon_id
  JOIN observation_photos op ON o.id = op.observation_id
  JOIN photos p ON p.id = op.photo_id
  WHERE t.is_active = true
  AND ( t.id IN ( #{ ancestry_string.gsub( "/","," ) } ) OR t.ancestry = '#{ ancestry_string }' OR t.ancestry LIKE ( '#{ ancestry_string }/%' ) )
  AND ( select count(*) from conservation_statuses ct where ct.taxon_id=t.id AND ct.iucn=70 AND ct.place_id IS NULL ) = 0
  AND p.type = 'LocalPhoto'
  GROUP BY t.id;
SQL
taxonomy = ActiveRecord::Base.connection.execute( sql_query )
photo_counts = taxonomy.map{|row| [row["taxa_id"], row["count"].to_i]}.to_h

# Keep only the leaves with enough downstream data
enough = []
ranks = Taxon::RANK_LEVELS.values.uniq.sort
standard_ranks = Taxon::RANK_LEVELS.select{ |k,v| ( Taxon::PREFERRED_RANKS.include? k ) && v > Taxon::SUBSPECIES_LEVEL && v != Taxon::SUPERFAMILY_LEVEL }.values.reverse
ranks[1..-1].each do |i|
  puts i
  enough_set = enough.map{ |row| row[:taxon_id] }.to_set
  Taxon.where("( ancestry = '#{ ancestry_string }' OR ancestry LIKE ( '#{ ancestry_string }/%' ) ) AND is_active = true AND rank_level = ?", i ).
  where("( select count(*) from conservation_statuses ct where ct.taxon_id=taxa.id AND ct.iucn=70 AND ct.place_id IS NULL ) = 0").each do |t|
    puts "\t#{t.id}"
    dset = t.descendants.pluck( :id ).to_set
    if ( dset & enough_set ).count > 0
      # internode
      enough << {
        taxon_id: t.id
      } 
    else
      # leaf
      if [
          photo_counts[t.id.to_s],
          t.descendants.pluck( :id ).map{ |j|
            photo_counts[j.to_s]
          }
        ].flatten.compact.sum >= 60
        enough << {
          taxon_id: t.id
        } 
      end
    end
  end
end
if root.rank_level == Taxon::ROOT_LEVEL
  enough_set = [enough.map{ |row| row[:taxon_id] }].flatten.to_set; nil
else
  enough_set = [enough.map{ |row| row[:taxon_id] },root.id].flatten.to_set
end


# Fetch the taxa
taxa = Taxon.find( enough_set.to_a ); nil
results = taxa.map{|i|
    {
      id: i[:id],
      name: i[:name],
      rank_level: i[:rank_level],
      ancestors: i[:ancestry].split( "/" ).select{ |j| enough_set.include? j.to_i }.map{ |j| j.to_i }
    }
  }; nil


# Add 'missing' nodes (e.g. if Class->Family, insert Order)
results_hash = results.map{ |i| [i[:id],i[:rank_level]] }.to_h; nil
kntr=0
fake_key = {}
continue = true
while continue
  if row = results.select{ |i| ( standard_ranks.select{ |sr| sr > i[:rank_level] && sr < root.rank_level } - i[:ancestors].map{ |k| results_hash[k].to_i } ).count > 0 }.first
    puts kntr
    puts row[:id]
    ancestors = row[:ancestors].map{ |i| results.select{ |j| j[:id]==i }.first }
    standard_rank_levels = standard_ranks.select{ |sr| sr>row[:rank_level] && sr < root.rank_level }
    actual_rank_levels = row[:ancestors].map{ |k| results.select{ |j| j[:id]==k }.first[:rank_level].to_i }
    missing_rank_level = ( standard_rank_levels - actual_rank_levels ).first
    puts missing_rank_level
    child_rank_level = actual_rank_levels.select{ |a| a < missing_rank_level }.first
    if child_rank_level.nil?
      child_rank_level = row[:rank_level].to_i
      child = row
    else
      child = ancestors.select{ |a| a[:rank_level] == child_rank_level }.first
    end
    parent_rank_level = actual_rank_levels.select{ |a| a > missing_rank_level }.last

    new_node = {
      id: ( 0...7 ).map { ( 65 + rand( 26 ) ).chr }.join,
      name: nil,
      rank_level: missing_rank_level,
      ancestors: ancestors.select{ |a| a[:rank_level] >= parent_rank_level }.map{ |a| a[:id] }
    }
    results_hash = results_hash.merge( { new_node[:id] => new_node[:rank_level] } )
    results.select{ |i| i[:ancestors].include? child[:id] }.map{ |i| i[:ancestors].insert( i[:ancestors].index( child[:id] ), new_node[:id] ) }
    results.select{ |i| i[:id]==child[:id] }.map{ |i| i[:ancestors].append( new_node[:id] ) }
    results << new_node
    fake_key[new_node[:id]] = child[:id]
    kntr+=1
  else
    continue = false
  end
end

# Remove non standard nodes and update ancestry
to_del = results.select{ |a| !standard_ranks.include? a[:rank_level].to_i }; nil
to_del_set = to_del.map{ |a| a[:id] }.to_set; nil
new_res = results.select{ |a| standard_ranks.include? a[:rank_level].to_i }.
  map{ |a| 
    {
      id: a[:id],
      name: a[:name],
      rank_level: a[:rank_level],
      ancestors: [root.ancestor_ids[1..-1], a[:ancestors].select{ |i| !to_del_set.include? i }].flatten.compact
    }
    }; nil
unless root.rank_level == Taxon::ROOT_LEVEL
  root.ancestors[1..-1].each do |row|
    new_res << {
      id: row.id,
      name: row.name,
      rank_level: row.rank_level,
      ancestors: row.ancestor_ids[1..-1]
    }
  end
end

internodes = new_res.map{ |a| a[:ancestors] }.flatten.uniq.to_set; nil

# Map between taxon_id and class id
class_hash = {}
standard_ranks.each do |j|
  taxon_ids = new_res.select{ |i| i[:rank_level] == j }.map{ |i| i[:id] }
  indexes = ( 0..( taxon_ids.count - 1 ) ).step( 1 ).to_a
  class_hash = class_hash.merge( taxon_ids.zip( indexes ).to_h )
end
unless root.rank_level == Taxon::ROOT_LEVEL
  class_hash = class_hash.merge( root.ancestor_ids[1..-1].map{ |a| a }.zip( [0,0] ).to_h ); nil
end

# Export the taxonomy
CSV.open( "#{directory}/taxonomy_data.csv", "wb" ) do |csv|
  csv << ["parent_taxon_id", "taxon_id", "class_id", "rank_level", "name"]
  new_res.each do |row|
    csv << [ row[:ancestors].last, row[:id], class_hash[row[:id]], row[:rank_level].to_i, row[:name] ]
  end
end

# Some code for rendering out json to vizualize here http://loarie.github.io/treenew5.html
=begin
def go_deeper( row, nr )
  children = nr.select{ |i| i[:ancestors].last==row[:id] }
  fixed_children = []
  children.each do |child|
    child[:name] = child[:id] if child[:name].nil?
    rr = { id: child[:id], name: child[:name] }
    childd = go_deeper( rr, nr )
    fixed_children << childd
  end
  if fixed_children.count > 0
    row[:children] = fixed_children
  end
  return row
end

if root.rank_level == Taxon::ROOT_LEVEL
  subject = { id: root.id, name: root.name, children: [] }
  new_res.select{ |i| i[:ancestors].empty? }.each do |row|
    rr = {id: row[:id], name: row[:name]}
    subject[:children] << go_deeper( rr, new_res ); nil
  end
else
  ss = new_res.select{ |a| a[:id] == root.ancestor_ids[1]}.first
  subject = {id: ss[:id], name: ss[:name] }
  subject = go_deeper( subject, new_res )
end

#puts subject.to_json
File.open( "/home/inaturalist/subject.json", "w" ) do |f|
  f.write( subject.to_json )
end
=end

# Part 2: Fetch the photos on the taxonomy

# Find the photos
test_data = []
train_data = []
val_data = []
new_res.each do |row|
  row_id = row[:id]
  while !row_id.is_a? Numeric
    row_id = fake_key[row_id]
  end
  ancestry = Taxon.find(row_id).ancestry+"/#{row_id}"
  multitask_labels = [
    row[:ancestors].map{ |i| class_hash[i] }, 
    class_hash[row[:id]]
  ].flatten
  multitask_labels = multitask_labels.append( Array.new(7 - multitask_labels.count, 0) ).flatten
  multitask_texts = [
    row[:ancestors], 
    row[:id]
  ].flatten.map{|i| i.to_s}
  multitask_texts = multitask_texts.append( Array.new(7 - multitask_texts.count, nil) ).flatten
  
  multitask_weights = Array.new( 7, 1 )
  multitask_weights[( 7 + 1 ) - row[:rank_level] / 10..7] = Array.new( row[:rank_level] / 10 - 1, 0 )
  puts row_id
  
  if internodes.include? row_id
    sql_query = <<-SQL
      SELECT op.photo_id AS id, p.medium_url AS filename, p.metadata AS metadata, p.file_content_type AS file_content_type
      FROM observations o
      JOIN taxa t ON t.id = o.taxon_id
      JOIN observation_photos op ON op.observation_id = o.id
      JOIN photos p ON op.photo_id = p.id
      WHERE ( t.id = #{ row_id } OR t.ancestry = '#{ ancestry }' OR t.ancestry LIKE ( '#{ ancestry }/%' ) )
      AND t.rank_level > #{ row[:rank_level] - 10 }
      AND p.type = 'LocalPhoto'
      AND ( select count(*) from conservation_statuses ct where ct.taxon_id=t.id AND ct.iucn=70 AND ct.place_id IS NULL ) = 0
      LIMIT #{ 1000 + test_count };
    SQL
  else
    sql_query = <<-SQL
      SELECT op.photo_id AS id, p.medium_url AS filename, p.metadata AS metadata, p.file_content_type AS file_content_type
      FROM observations o
      JOIN taxa t ON t.id = o.taxon_id
      JOIN observation_photos op ON op.observation_id = o.id
      JOIN photos p ON op.photo_id = p.id
      WHERE ( t.id = #{ row_id } OR t.ancestry = '#{ ancestry }' OR t.ancestry LIKE ( '#{ ancestry }/%' ) )
      AND p.type = 'LocalPhoto'
      AND ( select count(*) from conservation_statuses ct where ct.taxon_id=t.id AND ct.iucn=70 AND ct.place_id IS NULL ) = 0
      LIMIT #{ 1000 + test_count };
    SQL
  end
  photos = ActiveRecord::Base.connection.execute( sql_query ).map{ |i| i }; nil  
  if photos.count >= test_count
    # 30 in test, of the remainder, 10% up to 10 in val, the rest in train
    train_val_count = photos[test_count..photos.length].count
    train_count = ( train_val_count * ( 1 - val_percent ) ).round
    val_count = photos.length - test_count - train_count
    if val_count > val_thres
      train_count = train_val_count - val_thres
      val_count = val_thres
    end
    test_photos = photos[0..( test_count - 1 )]
    train_photos = photos[test_count..( ( test_count - 1 ) + train_count )]
    val_photos = photos[( test_count + train_count )..photos.length]
  else
    test_count = photos.count
    test_photos = photos[0..( test_count - 1 )]
    train_photos = nil
    val_photos = nil
  end
  test_photos.each do |item|
    begin
      height = item["metadata"].nil? ? nil : YAML.load( item["metadata"] )[:dimensions][:medium][:height]
      width = item["metadata"].nil? ? nil : YAML.load( item["metadata"] )[:dimensions][:medium][:width]
    rescue
      height = nil
      width = nil
    end
    out_row = {
      filename: item["filename"],
      id: item["id"],
      multitask_labels: multitask_labels,
      multitask_texts: multitask_texts,
      multitask_weights: multitask_weights,
      height: height,
      width: width,
      file_content_type: item["file_content_type"]
    }
    test_data << out_row
  end
  next unless photos.count > test_count
  unless train_photos.nil?
    train_photos.each do |item|
      begin
        height = item["metadata"].nil? ? nil : YAML.load( item["metadata"] )[:dimensions][:medium][:height]
        width = item["metadata"].nil? ? nil : YAML.load( item["metadata"] )[:dimensions][:medium][:width]
      rescue
        height = nil
        width = nil
      end
      out_row = {
        filename: item["filename"],
        id: item["id"],
        multitask_labels: multitask_labels,
        multitask_texts: multitask_texts,
        multitask_weights: multitask_weights,
        height: height,
        width: width,
        file_content_type: item["file_content_type"]
      }
      train_data << out_row
    end
  end
  unless val_photos.nil?
    val_photos.each do |item|
      begin
        height = item["metadata"].nil? ? nil : YAML.load( item["metadata"] )[:dimensions][:medium][:height]
        width = item["metadata"].nil? ? nil : YAML.load( item["metadata"] )[:dimensions][:medium][:width]
      rescue
        height = nil
        width = nil
      end
      out_row = {
        filename: item["filename"],
        id: item["id"],
        multitask_labels: multitask_labels,
        multitask_texts: multitask_texts,
        multitask_weights: multitask_weights,
        height: height,
        width: width,
        file_content_type: item["file_content_type"]
      }
      val_data << out_row
    end
  end
end

# Reality check code
=begin
test_data.each do |row|
  ind = row[:multitask_weights].index{ |a| a==0 }
  ind = ind.nil? ? 6 : (ind - 1)
  rank_level = (7-ind)*10
  taxon_id = row[:multitask_texts][ind].to_i
  next if taxon_id == 0
  class_id = row[:multitask_labels][ind].to_i
  unless (class_hash[taxon_id] == class_id) && (Taxon.find(taxon_id).rank_level.to_i == rank_level)
    puts row[:id]
  end
end
=end

puts test_data.count
puts train_data.count
puts val_data.count

# Write out the photo data
File.open("#{directory}/test_data.json","w") do |f|
  f.write(test_data.to_json)
end
File.open("#{directory}/train_data.json","w") do |f|
  f.write(train_data.to_json)
end
File.open("#{directory}/val_data.json","w") do |f|
  f.write(val_data.to_json)
end
