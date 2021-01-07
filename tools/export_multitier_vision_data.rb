OPTS = Optimist::options do
    banner <<-EOS

THE DESCRIPTION

Usage:

  rails runner tools/export_multitier_vision_data.rb

Options:
EOS
  opt :root_dir, "Root directory in which to save the export",
    type: :string, short: "-r", default: "./"
  opt :dir, "Directory name for this export",
    type: :string, short: "-d", default: "slim_export_YYYYMMDD"
  opt :root_taxon_id, "ID of the taxon whose data will be exported",
    type: :string, short: "-t"
  opt :filter_taxon_ids, "IDs of the taxa whose data will be exported",
    type: :integers, short: "-i"
end

if OPTS[:dir] == "slim_export_YYYYMMDD"
  datestring = Time.now.strftime( "%Y%m%d" )
  OPTS[:dir] = "slim_export_#{datestring}"
end

if OPTS[:filter_taxon_ids]
  filter_taxa = Taxon.where( id: OPTS[:filter_taxon_ids] )
  if filter_taxa.empty?
    puts "Could not find filter taxa. Exiting.\n\n"
    exit( 0 )
  end
  filter_taxon_ids = filter_taxa.map{ |t| Taxon.self_and_descendants_of(t).pluck(:id) }.flatten.uniq
  filter_taxon_ancestor_ids = filter_taxa.map{ |t| t.ancestry.split("/").map(&:to_i) }.flatten.uniq
else
  filter_taxon_ids = nil
end

puts "\n\n"
unless Dir.exists?( OPTS[:root_dir] )
  puts "Root directory `#{OPTS[:root_dir]}` does not exist. Exiting.\n\n"
  exit( 0 )
end

export_dir_fullpath = File.join( OPTS[:root_dir], OPTS[:dir] )
if Dir.exists?( export_dir_fullpath )
  puts "Export directory `#{export_dir_fullpath}` already exists. Exiting.\n\n"
  exit( 0 )
end
FileUtils.mkdir( export_dir_fullpath )
puts "Export directory: #{export_dir_fullpath}"

root_taxon = OPTS[:root_taxon_id] ?
  Taxon.where( id: OPTS[:root_taxon_id] ).first : Taxon::LIFE
if !root_taxon
  puts "Invalid root taxon. Exiting.\n\n"
  exit( 0 )
end
puts "Root taxon: #{root_taxon.name} [#{root_taxon.id}]"

TRAIN_FLOOR = 50
TRAIN_CEIL = 1000
TEST_NUM = 25
VAL_NUM = 25
DATA_CSV_COLUMNS = [:id, :filename, :multitask_labels, :multitask_texts, :file_content_type]
BAD_OBSERVATION_IDS = { }

puts "Find obs with failing quality_metrics (ex. captive) and unresolved flags..."
quality_metrics_query = <<-SQL
  SELECT DISTINCT observation_id
  FROM (
    SELECT observation_id
    FROM quality_metrics
    WHERE metric != 'wild'
    GROUP BY observation_id, metric
    HAVING
      count( CASE WHEN agree THEN 1 ELSE null END ) < count( CASE WHEN agree THEN null ELSE 1 END )
  ) as subq;
SQL

QualityMetric.connection.execute( quality_metrics_query ).each do |row|
  BAD_OBSERVATION_IDS[row["observation_id"].to_i] = true
end

flags_query = <<-SQL
  SELECT DISTINCT flaggable_id
  FROM flags f
  WHERE f.flaggable_type = 'Observation' AND NOT f.resolved;
SQL

Flag.connection.execute( flags_query ).each do |row|
  BAD_OBSERVATION_IDS[row["flaggable_id"].to_i] = true
end

extinct_taxon_ids = ConservationStatus.where( iucn: Taxon::IUCN_EXTINCT, place_id: nil ).distinct.pluck( :taxon_id )

standard_ranks = Taxon::RANK_LEVELS.select do |k,v|
  Taxon::PREFERRED_RANKS.include?( k ) &&
  v > Taxon::SUBSPECIES_LEVEL &&
  v != Taxon::SUPERFAMILY_LEVEL
end.values.reverse

ancestry_string = root_taxon.rank_level == Taxon::ROOT_LEVEL ?
  "#{ root_taxon.id }" : "#{ root_taxon.ancestry }/#{ root_taxon.id }"
if root_taxon.rank_level == Taxon::ROOT_LEVEL
  root_ancestors = []
else
  root_ancestors = root_taxon.ancestors.select do |ancestor|
    standard_ranks.include?( ancestor.rank_level )
  end
end

# Part 1: determine the taxonomy

if filter_taxon_ids
  obs_taxon_filter_clause = "AND ( observations.community_taxon_id IN ( #{filter_taxon_ids.join( ',' )} )
      OR observations.taxon_id IN ( #{filter_taxon_ids.join( ',' )} ) )"
end

# Create a hash of the candidate observation counts for each node descending from the root (*where candidate means photos, no flags, no failing quality_metrics other than 'wild') for test (must have CID) and otherwise
CANDIDATE_OBSERVATIONS_SQL = <<-SQL
  SELECT
    observations.id,
    observations.taxon_id,
    observations.community_taxon_id,
    observations.user_id,
    observations.quality_grade,
    observations.license,
    COUNT( failing_metrics.observation_id ) AS num_failing_metrics,
    COALESCE( observations.community_taxon_id, observations.taxon_id ) AS joinable_taxon_id
  FROM
    observations
      LEFT OUTER JOIN (
        SELECT observation_id, metric
        FROM quality_metrics
        WHERE metric != 'wild'
        GROUP BY observation_id, metric
        HAVING count( CASE WHEN agree THEN 1 ELSE null END ) < count( CASE WHEN agree THEN null ELSE 1 END )
      ) failing_metrics ON failing_metrics.observation_id = observations.id
      LEFT OUTER JOIN flags ON flags.flaggable_type = 'Observation' AND flags.flaggable_id = observations.id AND NOT flags.resolved
  WHERE
    observations.observation_photos_count > 0
    AND ( observations.community_taxon_id IS NOT NULL OR observations.taxon_id IS NOT NULL )
    #{ obs_taxon_filter_clause }
  GROUP BY
    observations.id
  HAVING
    COUNT( failing_metrics.observation_id ) = 0
    AND COUNT( flags.id ) = 0
SQL

sql_query = <<-SQL
  SELECT t.id AS taxa_id, COUNT( * )
  FROM taxa t
  JOIN ( #{CANDIDATE_OBSERVATIONS_SQL} ) o ON o.taxon_id = t.id
  WHERE t.is_active = true
  AND o.community_taxon_id IS NOT NULL AND o.community_taxon_id = o.taxon_id
  AND ( t.id = #{root_taxon.id} OR t.ancestry = '#{ ancestry_string }' OR t.ancestry LIKE ( '#{ ancestry_string }/%' ) )
  AND t.id NOT IN ( #{extinct_taxon_ids.join( "," )} )
  GROUP BY t.id;
SQL
puts "Looking up taxon CID supported obs counts..."
taxonomy = ActiveRecord::Base.connection.execute( sql_query )
test_obs_counts = taxonomy.map{|row| [row["taxa_id"], row["count"].to_i]}.to_h

sql_query = <<-SQL
  SELECT t.id AS taxa_id, COUNT( * )
  FROM taxa t
  JOIN ( #{CANDIDATE_OBSERVATIONS_SQL} ) o ON o.taxon_id = t.id
  WHERE t.is_active = true
  AND ( t.id = #{root_taxon.id} OR t.ancestry = '#{ ancestry_string }' OR t.ancestry LIKE ( '#{ ancestry_string }/%' ) )
  AND t.id NOT IN ( #{extinct_taxon_ids.join( "," )} )
  GROUP BY t.id;
SQL
puts "Looking up taxon obs counts..."
taxonomy = ActiveRecord::Base.connection.execute( sql_query )
total_obs_counts = taxonomy.map{|row| [row["taxa_id"], row["count"].to_i]}.to_h


# Keep only the leaves with enough downstream data
puts "Trimming taxonomy based on obs counts..."
enough = []
species_and_above_rank_levels =
  Taxon::RANK_LEVELS.values.uniq.sort - [Taxon::RANK_LEVELS["subspecies"]]
species_and_above_rank_levels.each do |rank_level|
  enough_set = enough.map{ |row| row[:taxon_id] }.to_set
  taxa_scope = Taxon.where( "( ancestry = '#{ ancestry_string }' OR ancestry LIKE ( '#{ ancestry_string }/%' ) )" ).
    where( "is_active = true AND rank_level = ?", rank_level ).
    where( "id NOT IN ( ? )", extinct_taxon_ids )
  if filter_taxon_ids
    taxa_scope = taxa_scope.where(id: filter_taxon_ids + filter_taxon_ancestor_ids)
  end
  taxa_scope.each do |t|
    dset = t.descendants.pluck( :id ).to_set
    # internode
    if ( dset & enough_set ).count > 0
      enough << {
        taxon_id: t.id, count: nil
      } 
    # leaf
    elsif ( [
          test_obs_counts[t.id.to_s],
          t.descendants.pluck( :id ).map{ |j|
            test_obs_counts[j.to_s]
          }
        ].flatten.compact.sum >= TEST_NUM + VAL_NUM )
        total_count = [
          total_obs_counts[t.id.to_s],
          t.descendants.pluck( :id ).map{ |j|
            total_obs_counts[j.to_s]
          }
        ].flatten.compact.sum
        enough << { taxon_id: t.id, count: total_count } if total_count >= ( TRAIN_FLOOR + VAL_NUM + TEST_NUM ) 
    end
  end
end
if root_taxon.rank_level == Taxon::ROOT_LEVEL
  enough_set = [enough.map{ |row| row[:taxon_id] }].flatten.to_set; nil
else
  enough_set = [enough.map{ |row| row[:taxon_id] }, root_taxon.id].flatten.to_set
end

# Fetch the taxa
taxa = Taxon.find( enough_set.to_a ); nil
export_taxonomy = taxa.map{|i|
    {
      id: i[:id],
      name: i[:name],
      rank_level: i[:rank_level],
      ancestors: i[:ancestry].split( "/" ).map{ |j| j.to_i } - [Taxon::LIFE.id],
      count: enough.select{|j| j[:taxon_id]==i[:id]}.map{|j| j[:count]}.first
    }
  }; nil

# add in ancestors of the exported taxon
unless root_taxon.rank_level == Taxon::ROOT_LEVEL
  j = 2
  root_ancestors.reverse.each do |row|
    export_taxonomy << {
      id: row.id,
      name: row.name,
      rank_level: row.rank_level,
      ancestors: root_ancestors.map{|i| i.id}[0..-j],
      count: nil
    }
    j+=1
  end
end

INTERNODES = export_taxonomy.map{ |a| a[:ancestors] }.flatten.uniq.to_set; nil

taxon_ids = export_taxonomy.select{ |i| !INTERNODES.include? i[:id] }.map{ |i| i[:id] }
indexes = ( 0..( taxon_ids.count - 1 ) ).step( 1 ).to_a
LEAF_CLASS_HASH = taxon_ids.zip( indexes ).to_h

# Export the taxonomy
CSV.open( "#{export_dir_fullpath}/taxonomy_data.csv", "wb" ) do |csv|
  csv << ["parent_taxon_id", "taxon_id", "rank_level", "leaf_class_id", "name"]
  export_taxonomy.each do |row|
    csv << [ row[:ancestors].last, row[:id], row[:rank_level].to_f, LEAF_CLASS_HASH[row[:id]], row[:name] ]
  end
end; nil

puts "#{export_taxonomy.count} nodes: #{taxon_ids.count} leaves and #{INTERNODES.count} internodes"

# Part 2: Fetch the photos on the taxonomy

def photo_item_to_csv_row( item, labels, texts )
  row_hash = {
    filename: item["filename"].sub(/\?.*/,''),
    id: item["id"],
    multitask_labels: labels,
    multitask_texts: texts,
    file_content_type: item["file_content_type"]
  }
  DATA_CSV_COLUMNS.map{ |c| row_hash[c] }
end

def process_photos_for_taxon_row( row, test_csv, train_csv, val_csv )
  row_id = row[:id]
  puts "working on taxon #{row_id}..."
  
  while !row_id.is_a? Numeric
    row_id = FAKE_KEY[row_id]
  end
  ancestry = Taxon.find(row_id).ancestry+"/#{row_id}"
  multitask_label = LEAF_CLASS_HASH[row[:id]].nil? ? 0 : LEAF_CLASS_HASH[row[:id]]
  multitask_text = LEAF_CLASS_HASH[row[:id]].nil? ? nil : row[:id].to_s
    
  taxon_ids_scope = Taxon.where("taxa.id = #{ row_id } OR taxa.ancestry = '#{ ancestry }' OR taxa.ancestry LIKE ( '#{ ancestry }/%' )").
    where("( select count(*) from conservation_statuses ct where ct.taxon_id=taxa.id AND ct.iucn=70 AND ct.place_id IS NULL ) = 0")
  if INTERNODES.include? row_id
    taxon_ids_scope = taxon_ids_scope.where("taxa.rank_level > #{ row[:rank_level] - 10 }")
  end
  taxon_ids = taxon_ids_scope.pluck( :id )
  if taxon_ids.empty?
    return
  end
  
  base_sql_query = <<-SQL
      SELECT op.photo_id AS id, o.id AS oid
      FROM observations o
      JOIN observation_photos op ON op.observation_id = o.id
      JOIN photos p ON op.photo_id = p.id
      WHERE p.original_url NOT LIKE '%attachment%'
      AND p.original_url NOT LIKE '%copyright%'
      AND p.type = 'LocalPhoto'
      AND o.taxon_id IN ( #{taxon_ids.join( "," )} )
  SQL

  sql_query = base_sql_query + "AND ( o.community_taxon_id IS NOT NULL AND o.community_taxon_id = o.taxon_id );"
  raw_photos_cid = ActiveRecord::Base.connection.execute( sql_query ).map{ |i| {id: i["id"].to_i, oid: i["oid"].to_i} }; nil
  sql_query = base_sql_query + "AND ( o.community_taxon_id IS NULL OR o.community_taxon_id != o.taxon_id );"
  raw_photos_no_cid = ActiveRecord::Base.connection.execute( sql_query ).map{ |i| {id: i["id"].to_i, oid: i["oid"].to_i} }; nil
  raw_photo_ids = [raw_photos_cid.shuffle,raw_photos_no_cid.shuffle].flatten; nil
  photo_ids = []
  raw_photo_ids.each do |raw_photo_id|
    unless BAD_OBSERVATION_IDS[raw_photo_id[:oid]]
      photo_ids << {id: raw_photo_id[:id], oid: raw_photo_id[:oid]}
    end
  end
  photo_ids = photo_ids[0..( TEST_NUM + VAL_NUM + TRAIN_CEIL - 1 )]
  photo_ids[0..TEST_NUM].map{|i| i[:set] = "test"}
  photo_ids[TEST_NUM..( TEST_NUM  + VAL_NUM - 1 )].map{|i| i[:set] = "val"}
  photo_ids[( TEST_NUM  + VAL_NUM )..( TEST_NUM + VAL_NUM + TRAIN_CEIL - 1 )].map{|i| i[:set] = "train"}

  base_sql_query = <<-SQL
    SELECT DISTINCT p.id AS id, p.medium_url AS filename, p.file_content_type AS file_content_type, o.id AS observation_id
    FROM photos p
    JOIN observation_photos op ON op.photo_id = p.id
    JOIN observations o ON op.observation_id = o.id
  SQL

  ids = photo_ids.select{|i| i[:set]=="train"}.map{|i| i[:id]}.join( "," )
  oids = photo_ids.select{|i| i[:set]=="train"}.map{|i| i[:oid]}.join( "," )
  sql_query = base_sql_query + " AND o.id IN ( #{oids} ) AND p.id IN ( #{ids} );"
  train_photos = ActiveRecord::Base.connection.execute( sql_query ).map{ |i| i }; nil
  
  ids = photo_ids.select{|i| i[:set]=="val"}.map{|i| i[:id]}.join( "," )
  oids = photo_ids.select{|i| i[:set]=="val"}.map{|i| i[:oid]}.join( "," )
  sql_query = base_sql_query + " AND o.id IN ( #{oids} ) AND p.id IN ( #{ids} );"
  val_photos = ActiveRecord::Base.connection.execute( sql_query ).map{ |i| i }; nil

  ids = photo_ids.select{|i| i[:set]=="test"}.map{|i| i[:id]}.join( "," )
  oids = photo_ids.select{|i| i[:set]=="test"}.map{|i| i[:oid]}.join( "," )
  sql_query = base_sql_query + " AND o.id IN ( #{oids} ) AND p.id IN ( #{ids} );"
  test_photos = ActiveRecord::Base.connection.execute( sql_query ).map{ |i| i }; nil

  puts "\t #{train_photos.count} training photos"

  val_photos.each do |item|
    out_row = photo_item_to_csv_row( item, multitask_label, multitask_text )
    val_csv << out_row
  end
  test_photos.each do |item|
    out_row = photo_item_to_csv_row( item, multitask_label, multitask_text )
    test_csv << out_row
  end
  train_photos.each do |item|
    out_row = photo_item_to_csv_row( item, multitask_label, multitask_text )
    train_csv << out_row
  end
end

photos_start_time = Time.now
processed_count = 0
total_taxa_count = export_taxonomy.select{ |r| !INTERNODES.include?( r[:id] ) }.length
puts "Starting to processing photos for #{total_taxa_count} taxa..."
CSV.open( "#{export_dir_fullpath}/test_data.csv", "w" ) do |test_csv|
  CSV.open( "#{export_dir_fullpath}/train_data.csv", "w" ) do |train_csv|
    CSV.open( "#{export_dir_fullpath}/val_data.csv", "w" ) do |val_csv|
      test_csv << DATA_CSV_COLUMNS
      train_csv << DATA_CSV_COLUMNS
      val_csv << DATA_CSV_COLUMNS
      pp Benchmark.measure{
        export_taxonomy.each do |row|
          next if INTERNODES.include? row[:id]
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
end; nil

#copy the file to script
src = "#{FileUtils.pwd}/tools/export_multitier_vision_data.rb"
FileUtils.cp( src, "#{export_dir_fullpath}/export_multitier_vision_data.rb" )

puts "Done\n\n"



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

if root_taxon.rank_level == Taxon::ROOT_LEVEL
  subject = { id: root_taxon.id, name: root_taxon.name, children: [] }
  export_taxonomy.select{ |i| i[:ancestors].empty? }.each do |row|
    rr = {id: row[:id], name: row[:name]}
    subject[:children] << go_deeper( rr, export_taxonomy ); nil
  end
else
  ss = export_taxonomy.select{ |a| a[:id] == root_taxon.ancestor_ids[1]}.first
  subject = {id: ss[:id], name: ss[:name] }
  subject = go_deeper( subject, export_taxonomy )
end

#puts subject.to_json
File.open( "/home/inaturalist/subject.json", "w" ) do |f|
  f.write( subject.to_json )
end
=end
