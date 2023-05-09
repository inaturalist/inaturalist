root_id = 47825
export_dir_fullpath = "/home/inaturalist/loarie"

CUTOFF = 50
root_taxon = Taxon.where( id: root_id ).first

puts "Find obs with failing quality_metrics (ex. captive) and unresolved flags..."
BAD_OBSERVATION_IDS = { }
quality_metrics_query = <<-SQL
  SELECT DISTINCT observation_id
  FROM (
    SELECT observation_id
    FROM quality_metrics
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

BAD_OBSERVATION_SET = BAD_OBSERVATION_IDS.keys.to_set

extinct_taxon_ids = ConservationStatus.where( iucn: Taxon::IUCN_EXTINCT, place_id: nil ).distinct.pluck( :taxon_id )
hybrid_taxon_ids = Taxon.where( "is_active = true AND rank IN (?)", ["hybrid","genushybrid"]).pluck( :id )
extinct_and_hybrid_taxon_ids = [extinct_taxon_ids, hybrid_taxon_ids].flatten.uniq

ancestry_string = root_taxon.rank_level == Taxon::ROOT_LEVEL ?
  "#{ root_taxon.id }" : "#{ root_taxon.ancestry }/#{ root_taxon.id }"

CANDIDATE_OBSERVATIONS_SQL = <<-SQL
  SELECT
    o.id,
    o.taxon_id
  FROM
    observations o
      LEFT OUTER JOIN (
        SELECT observation_id, metric
        FROM quality_metrics
        GROUP BY observation_id, metric
        HAVING count( CASE WHEN agree THEN 1 ELSE null END ) < count( CASE WHEN agree THEN null ELSE 1 END )
      ) failing_metrics ON failing_metrics.observation_id = o.id
      LEFT OUTER JOIN flags ON flags.flaggable_type = 'Observation' AND flags.flaggable_id = o.id AND NOT flags.resolved
  WHERE
    o.observed_on IS NOT NULL
    AND (o.positional_accuracy IS NULL OR o.positional_accuracy < 1000)
    AND ((CASE WHEN o.private_latitude IS NULL THEN o.latitude ELSE o.private_latitude END) IS NOT NULL)
    AND ((CASE WHEN o.private_longitude IS NULL THEN o.longitude ELSE o.private_longitude END) IS NOT NULL)
    AND o.observation_photos_count > 0
    AND o.community_taxon_id IS NOT NULL AND o.community_taxon_id = o.taxon_id
  GROUP BY
    o.id
  HAVING
    COUNT( failing_metrics.observation_id ) = 0
    AND COUNT( flags.id ) = 0
SQL

sql_query = <<-SQL
  SELECT t.id AS taxa_id, COUNT( * )
  FROM taxa t
  JOIN ( #{CANDIDATE_OBSERVATIONS_SQL} ) o ON o.taxon_id = t.id
  WHERE t.is_active = true
  AND t.rank_level <= 10
  AND ( t.id = #{root_taxon.id} OR t.ancestry = '#{ ancestry_string }' OR t.ancestry LIKE ( '#{ ancestry_string }/%' ) )
  AND t.id NOT IN ( #{extinct_and_hybrid_taxon_ids.join( "," )} )
  GROUP BY t.id;
SQL
puts "Looking up taxon obs counts..."
taxonomy = ActiveRecord::Base.connection.execute( sql_query )
total_obs_counts = taxonomy.map{|row| [row["taxa_id"], row["count"].to_i]}.to_h

# Keep only the leaves with enough downstream data
puts "Trimming taxonomy based on obs counts..."
enough = []
rank_level = 10
taxa_scope = Taxon.where( "( ancestry = '#{ ancestry_string }' OR ancestry LIKE ( '#{ ancestry_string }/%' ) )" ).
  where( "is_active = true AND rank_level = ?", rank_level ).
  where( "id NOT IN ( ? )", extinct_and_hybrid_taxon_ids )
taxa_scope.each do |t|
  total_count = [
  	total_obs_counts[t.id],
    t.descendants.pluck( :id ).map{ |j|
      total_obs_counts[j]
     }
  ].flatten.compact.sum
  enough << { taxon_id: t.id, count: total_count } if total_count >= CUTOFF
end

# Fetch the taxa
export_taxonomy = []
enough.each_slice(200) do | batch |
  INatAPIService.taxa(id: batch.map{|a| a[:taxon_id]}).results.each do |result|
    if result["default_photo"]
      photo = result["default_photo"]["square_url"]
    else
      photo = nil
    end
    if result["preferred_common_name"]
      common_name = result["preferred_common_name"]
    else
      common_name = nil
    end
    export_taxonomy << {
      taxon_id: result["id"],
      default_photo: photo,
      common_name: common_name,
      latin_name: result["name"]
    }
  end
end

File.open("#{export_dir_fullpath}/spatial_test_taxa.json","w") do |f|
  f.write(export_taxonomy.to_json)
end

CSV.open("#{export_dir_fullpath}/spatial_test.csv", "w") do |csv|
  csv << ["id", "taxon_id", "latitude", "longitude", "date"]
  export_taxonomy.each do |row|
  	row_id = row[:taxon_id]
  	puts "working on taxon #{row_id}..."
  
  	ancestry = Taxon.find(row_id).ancestry+"/#{row_id}"
    
  	taxon_ids_scope = Taxon.where("taxa.id = #{ row_id } OR taxa.ancestry = '#{ ancestry }' OR taxa.ancestry LIKE ( '#{ ancestry }/%' )").
    	where("( select count(*) from conservation_statuses ct where ct.taxon_id=taxa.id AND ct.iucn=70 AND ct.place_id IS NULL ) = 0")
  	taxon_ids = taxon_ids_scope.pluck( :id )
  
  	base_sql_query = <<-SQL
      SELECT o.id, o.taxon_id,
      CASE WHEN o.private_longitude IS NULL THEN o.longitude ELSE o.private_longitude END AS lon,
      CASE WHEN o.private_latitude IS NULL THEN o.latitude ELSE o.private_latitude END AS lat,
      o.observed_on
      FROM observations o
   	  WHERE o.observed_on IS NOT NULL
      AND (o.positional_accuracy IS NULL OR o.positional_accuracy < 1000)
      AND ((CASE WHEN o.private_latitude IS NULL THEN o.latitude ELSE o.private_latitude END) IS NOT NULL)
      AND ((CASE WHEN o.private_longitude IS NULL THEN o.longitude ELSE o.private_longitude END) IS NOT NULL)
      AND o.observation_photos_count > 0
      AND o.community_taxon_id IS NOT NULL AND o.community_taxon_id = o.taxon_id
      AND o.taxon_id IN ( #{taxon_ids.join( "," )} )
  	SQL

  	taxon_points = ActiveRecord::Base.connection.execute( base_sql_query )
    taxon_points = taxon_points.select{|i| !( BAD_OBSERVATION_SET.include? i["id"] )}
  
  	taxon_points.each do |point|
      csv << [point["id"].to_i, row_id, point["lon"].to_f, point["lat"].to_f, point["observed_on"]]
  	end

    puts "\t #{taxon_points.count} points"
  end
end

