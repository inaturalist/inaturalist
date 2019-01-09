directory = "/home/inaturalist"
TEST_FLOOR = 30
TEST_CEIL = 30
TRAIN_FLOOR = 27
TRAIN_CEIL = 990
VAL_FLOOR = 3
VAL_CEIL = 10
VAL_PERCENT_OF_TRAIN = 0.1
ROOT_ID = 48460
DATA_CSV_COLUMNS = [:id, :filename, :multitask_labels, :multitask_texts, :multitask_weights, :file_content_type]

# Pick the root of some branch to export
root = Taxon.find( ROOT_ID )
ranks = Taxon::RANK_LEVELS.values.uniq.sort
standard_ranks = Taxon::RANK_LEVELS.select{ |k,v| ( Taxon::PREFERRED_RANKS.include? k ) && v > Taxon::SUBSPECIES_LEVEL && v != Taxon::SUPERFAMILY_LEVEL }.values.reverse
ancestry_string = root.rank_level == Taxon::ROOT_LEVEL ?
  "#{ root.id }" : "#{ root.ancestry }/#{ root.id }"
if root.rank_level == Taxon::ROOT_LEVEL
  root_ancestors = []
else
  root_ancestors = root.ancestors.select{ |a| standard_ranks.include? a.rank_level}
end

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
puts "Looking up taxon photo counts..."
taxonomy = ActiveRecord::Base.connection.execute( sql_query )
photo_counts = taxonomy.map{|row| [row["taxa_id"], row["count"].to_i]}.to_h

# Keep only the leaves with enough downstream data
puts "Trimming taxonomy based on photo counts..."
enough = []
ranks[1..-1].each do |i|
  #puts i
  enough_set = enough.map{ |row| row[:taxon_id] }.to_set
  Taxon.where("( ancestry = '#{ ancestry_string }' OR ancestry LIKE ( '#{ ancestry_string }/%' ) ) AND is_active = true AND rank_level = ?", i ).
  where("( select count(*) from conservation_statuses ct where ct.taxon_id=taxa.id AND ct.iucn=70 AND ct.place_id IS NULL ) = 0").each do |t|
    #puts "\t#{t.id}"
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
        ].flatten.compact.sum >= ( TEST_FLOOR + TRAIN_FLOOR + VAL_FLOOR)
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
puts "Adding missing taxonomy nodes..."
results_hash = results.map{ |i| [i[:id],i[:rank_level]] }.to_h; nil
FAKE_KEY = {}
continue = true
while continue
  if row = results.select{ |i| ( standard_ranks.select{ |sr| sr > i[:rank_level] && sr < root.rank_level } - i[:ancestors].map{ |k| results_hash[k].to_i } ).count > 0 }.first
    ancestors = row[:ancestors].map{ |i| results.select{ |j| j[:id]==i }.first }
    standard_rank_levels = standard_ranks.select{ |sr| sr>row[:rank_level] && sr < root.rank_level }
    actual_rank_levels = row[:ancestors].map{ |k| results.select{ |j| j[:id]==k }.first[:rank_level].to_i }
    missing_rank_level = ( standard_rank_levels - actual_rank_levels ).first
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
    FAKE_KEY[new_node[:id]] = child[:id]
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
      ancestors: [root_ancestors.map{|i| i.id}, a[:ancestors].select{ |i| !to_del_set.include? i }].flatten.compact
    }
    }; nil
unless root.rank_level == Taxon::ROOT_LEVEL
  root_ancestors.each do |row|
    new_res << {
      id: row.id,
      name: row.name,
      rank_level: row.rank_level,
      ancestors: root_ancestors
    }
  end
end

INTERNODES = new_res.map{ |a| a[:ancestors] }.flatten.uniq.to_set; nil

# Map between taxon_id and class id
CLASS_HASH = {}
standard_ranks.each do |j|
  taxon_ids = new_res.select{ |i| i[:rank_level] == j }.map{ |i| i[:id] }
  indexes = ( 0..( taxon_ids.count - 1 ) ).step( 1 ).to_a
  CLASS_HASH = CLASS_HASH.merge( taxon_ids.zip( indexes ).to_h )
end
unless root.rank_level == Taxon::ROOT_LEVEL
  CLASS_HASH = CLASS_HASH.merge( root_ancestors.map{ |a| a }.zip( [0,0] ).to_h ); nil
end

# Export the taxonomy
CSV.open( "#{directory}/taxonomy_data.csv", "wb" ) do |csv|
  csv << ["parent_taxon_id", "taxon_id", "class_id", "rank_level", "name"]
  new_res.each do |row|
    csv << [ row[:ancestors].last, row[:id], CLASS_HASH[row[:id]], row[:rank_level].to_i, row[:name] ]
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

def photo_item_to_csv_row( item, labels, texts, weights )
  row_hash = {
    filename: item["filename"],
    id: item["id"],
    multitask_labels: labels,
    multitask_texts: texts,
    multitask_weights: weights,
    file_content_type: item["file_content_type"]
  }
  DATA_CSV_COLUMNS.map{ |c| row_hash[c] }
end

def process_photos_for_taxon_row( row, test_csv, train_csv, val_csv )
  row_id = row[:id]
  while !row_id.is_a? Numeric
    row_id = FAKE_KEY[row_id]
  end
  ancestry = Taxon.find(row_id).ancestry+"/#{row_id}"
  multitask_labels = [
    row[:ancestors].map{ |i| CLASS_HASH[i] },
    CLASS_HASH[row[:id]]
  ].flatten
  multitask_labels = multitask_labels.append( Array.new(7 - multitask_labels.count, 0) ).flatten
  multitask_texts = [
    row[:ancestors], 
    row[:id]
  ].flatten.map{|i| i.to_s}
  multitask_texts = multitask_texts.append( Array.new(7 - multitask_texts.count, nil) ).flatten
  
  multitask_weights = Array.new( 7, 1 )
  multitask_weights[( 7 + 1 ) - row[:rank_level] / 10..7] = Array.new( row[:rank_level] / 10 - 1, 0 )
  
  rank_level_clause = ""
  if INTERNODES.include? row_id
    rank_level_clause = "AND t.rank_level > #{ row[:rank_level] - 10 }"
  end
  sql_query = <<-SQL
    SELECT op.photo_id AS id, p.medium_url AS filename, p.file_content_type AS file_content_type
    FROM observations o
    JOIN taxa t ON t.id = o.taxon_id
    JOIN observation_photos op ON op.observation_id = o.id
    JOIN photos p ON op.photo_id = p.id
    WHERE ( t.id = #{ row_id } OR t.ancestry = '#{ ancestry }' OR t.ancestry LIKE ( '#{ ancestry }/%' ) )
    #{ rank_level_clause }
    AND p.type = 'LocalPhoto'
    AND ( select count(*) from conservation_statuses ct where ct.taxon_id=t.id AND ct.iucn=70 AND ct.place_id IS NULL ) = 0
    LIMIT #{ TEST_CEIL + TRAIN_CEIL + VAL_CEIL };
  SQL
  photos = ActiveRecord::Base.connection.execute( sql_query ).map{ |i| i }; nil  
  if photos.count >= TEST_CEIL
    train_val_count = photos[TEST_CEIL..photos.length].count
    train_count = ( train_val_count * ( 1 - VAL_PERCENT_OF_TRAIN ) ).round
    val_count = photos.length - TEST_CEIL - train_count
    if val_count > VAL_CEIL
      train_count = train_val_count - VAL_CEIL
      val_count = VAL_CEIL
    end
    test_photos = photos[0..( TEST_CEIL - 1 )]
    train_photos = photos[TEST_CEIL..( ( TEST_CEIL - 1 ) + train_count )]
    val_photos = photos[( TEST_CEIL + train_count )..photos.length]
  else
    photos_count = photos.count
    test_photos = photos[0..( photos_count - 1 )]
    train_photos = nil
    val_photos = nil
  end
  test_photos.each do |item|
    out_row = photo_item_to_csv_row( item, multitask_labels, multitask_texts, multitask_weights )
    test_csv << out_row
  end
  return unless photos.count > TEST_CEIL
  unless train_photos.nil?
    train_photos.each do |item|
    out_row = photo_item_to_csv_row( item, multitask_labels, multitask_texts, multitask_weights )
      train_csv << out_row
    end
  end
  unless val_photos.nil?
    val_photos.each do |item|
    out_row = photo_item_to_csv_row( item, multitask_labels, multitask_texts, multitask_weights )
      val_csv << out_row
    end
  end
end


photos_start_time = Time.now
processed_count = 0
total_taxa_count = new_res.length
puts "Starting to processing photos for #{total_taxa_count} taxa..."
CSV.open( "#{directory}/test_data.csv", "w" ) do |test_csv|
  CSV.open( "#{directory}/train_data.csv", "w" ) do |train_csv|
    CSV.open( "#{directory}/val_data.csv", "w" ) do |val_csv|
      test_csv << DATA_CSV_COLUMNS
      train_csv << DATA_CSV_COLUMNS
      val_csv << DATA_CSV_COLUMNS
      pp Benchmark.measure{
        new_res.each do |row|
          process_photos_for_taxon_row( row, test_csv, train_csv, val_csv )
          processed_count += 1
          if processed_count % 50 == 0
            run_time = Time.now - photos_start_time
            avg_row_time = run_time / processed_count
            est_time_left = ( ( total_taxa_count - processed_count ) * avg_row_time ).round
            puts "   processed #{processed_count} of #{total_taxa_count} in #{ run_time.round }s; estimated #{est_time_left}s left"
          end
        end
      }
    end
  end
end


# Reality check code
=begin
TEST_DATA.each do |row|
  ind = row[:multitask_weights].index{ |a| a==0 }
  ind = ind.nil? ? 6 : (ind - 1)
  rank_level = (7-ind)*10
  taxon_id = row[:multitask_texts][ind].to_i
  next if taxon_id == 0
  class_id = row[:multitask_labels][ind].to_i
  unless (CLASS_HASH[taxon_id] == class_id) && (Taxon.find(taxon_id).rank_level.to_i == rank_level)
    puts row[:id]
  end
end
=end
