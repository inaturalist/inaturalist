require "Optimist"

OPTS = Optimist::options do
    banner <<-EOS

Create a FrequencyCell grid of the globe and populate each cell with its respective
FrequencyCellMonthTaxon, broken out by month observed. The all_taxa_counts API will
return leaf-style counts, and will include accumulation counts for all ancestors
up the taxonomic tree. This can generate 3 times as much data compared to just storing
leaves, so there is a final step to only keep counts of species and non-species
leaf taxa included in a vision export

Usage:

  rails runner tools/frequency_cells_populate.rb -t /path/to/vision-export-taxonomy.csv

where [options] are:
EOS
  opt :leaf_model_taxonomy_csv_path,
    "Path to model taxonomy file used to prune higher taxa.", short: "-t", type: :string
end

if OPTS.leaf_model_taxonomy_csv_path.blank?
  Optimist::die "Taxonomy CSV path required"
end

unless File.file?( OPTS.leaf_model_taxonomy_csv_path )
  Optimist::die "Taxonomy CSV path invalid"
end

PSQL = ActiveRecord::Base.connection
CELL_SIZE = 1 # degrees

# create an empty FrequencyCell grid of the globe
# this only needs to be run the first time, or if cell size changes
PSQL.execute( "TRUNCATE TABLE frequency_cells RESTART IDENTITY" )
Benchmark.measure do
  lat = -90
  while lat <= ( 90 - CELL_SIZE )
    lng = -180
    lat_cells = []
    while lng <= ( 180 - CELL_SIZE )
      lat_cells << "(#{lat},#{lng})"
      lng += CELL_SIZE
    end
    sql = "INSERT INTO frequency_cells (swlat, swlng) VALUES " + lat_cells.join( "," )
    PSQL.execute( sql )
    lat += CELL_SIZE
  end
end

# iterate through the grid and populate with FrequencyCellMonthTaxa
PSQL.execute( "TRUNCATE TABLE frequency_cell_month_taxa RESTART IDENTITY" )
Benchmark.measure do
  lat = -90
  while lat <= ( 90 - CELL_SIZE )
    lng = -180
    FrequencyCellMonthTaxon.transaction do
      while lng <= ( 180 - CELL_SIZE )
        params = {
          swlat: lat,
          swlng: lng,
          nelat: lat + CELL_SIZE,
          nelng: lng + CELL_SIZE,
          quality_grade: "research",
          taxon_is_active: "true"
        }
        response = INatAPIService.get( "/observations/taxa_counts_by_month",
          params, { retry_delay: 2.0, retries: 30, json: true }
        )
        month_of_year = response && response["results"] && response["results"]["month_of_year"]
        if month_of_year && !month_of_year.blank?
          frequency_cell = FrequencyCell.where( swlat: lat, swlng: lng ).first
          month_of_year.each do |month, leaf_counts|
            sql = "INSERT INTO frequency_cell_month_taxa (frequency_cell_id, month, taxon_id, count) VALUES " +
              leaf_counts.filter{ |r| !r["taxon_id"].blank? }.map {|r| "(#{frequency_cell.id},#{month},#{r["taxon_id"]},#{r["count"]})" }.join( "," )
            PSQL.execute( sql )
          end
          puts "Inserted #{lat},#{lng} :: #{month_of_year.map{ |m| m.length }.inject(:+)}"
        end
        lng += CELL_SIZE
      end
    end
    lat += CELL_SIZE
  end
end

relevant_higher_taxa = []
CSV.foreach( OPTS.leaf_model_taxonomy_csv_path, headers: true ) do |row|
  # ignore non-leaves
  next if row["leaf_class_id"].blank?
  # skip species and below
  next if row["rank_level"].to_i <= 10
  relevant_higher_taxa.push( row["taxon_id"].to_i )
end

# delete counts for non-species that aren't leaves in the vision export
PSQL.execute( "DELETE FROM frequency_cell_month_taxa WHERE taxon_id IN (
  SELECT distinct t.id FROM frequency_cell_month_taxa fr JOIN taxa t ON (fr.taxon_id=t.id)
  WHERE t.rank_level > 10 AND t.id NOT IN (#{relevant_higher_taxa.join(',')})
)")
