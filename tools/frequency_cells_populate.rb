OPTS = Optimist::options do
    banner <<-EOS

Create a FrequencyCell grid of the globe and populate each cell with its respective
FrequencyCellMonthTaxon, broken out by month observed. The all_taxa_counts API will
return leaf-style counts, and will include accumulation counts for all ancestors
up the taxonomic tree. This can generate 3 times as much data compared to just storing
leaves, so there is a final step to only keep counts of species and non-species
leaf taxa included in a vision export

Usage:

  rails runner tools/frequency_cells_populate.rb

EOS
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
start_time = Time.now
cells_counted = 0
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
          quality_grade: "research,needs_id",
          taxon_is_active: "true",
          identifications: "most_agree"
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
          puts "Inserted #{lat},#{lng} :: #{month_of_year.map{ |m,v| v.length }.inject(:+)}"
        end
        lng += CELL_SIZE
        cells_counted += 1
        total_time = Time.now - start_time
        if cells_counted % 100 === 0
          puts "#{cells_counted} cells in #{total_time}s, #{( cells_counted / total_time ).round( 2 )}cells/s"
        end
      end
    end
    lat += CELL_SIZE
  end
end
