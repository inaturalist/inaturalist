class FrequencyCell < ApplicationRecord
  CELL_SIZE = 1 # degrees

  def self.populate
    con = ActiveRecord::Base.connection
    # create an empty FrequencyCell grid of the globe
    # this only needs to be run the first time, or if cell size changes
    con.execute( "TRUNCATE TABLE frequency_cells RESTART IDENTITY" )
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
        con.execute( sql )
        lat += CELL_SIZE
      end
    end

    # iterate through the grid and populate with FrequencyCellMonthTaxa
    con.execute( "TRUNCATE TABLE frequency_cell_month_taxa RESTART IDENTITY" )
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
                con.execute( sql )
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
  end

  def self.export( path )
    sql = <<-SQL
      SELECT
        fc.swlat::varchar||'.'||fc.swlng::varchar as key,
        fcmt.month,
        fcmt.taxon_id,
        fcmt.count,
        CASE WHEN t.rank_level > 10 THEN 't' ELSE NULL END higher_taxon
      FROM
        frequency_cells fc
          JOIN frequency_cell_month_taxa fcmt ON fc.id = fcmt.frequency_cell_id
          JOIN taxa t ON fcmt.taxon_id = t.id
      WHERE
        t.rank_level = 10
      ORDER BY
        fc.swlat ASC,
        fc.swlng ASC
    SQL
    self.export_sql_to_csv( sql, path )
  end

  def self.export_taxa( path )
    sql = <<-SQL
      SELECT DISTINCT
        t.id, t.ancestry
      FROM
        frequency_cell_month_taxa fc
          JOIN taxa t ON fc.taxon_id=t.id
      WHERE t.rank_level=10
    SQL
    self.export_sql_to_csv( sql, path )
  end

  private
  def self.export_sql_to_csv( sql, path )
    csv_sql = "COPY (#{sql}) TO STDOUT WITH csv delimiter ',' header".gsub( /\s+/, " " )
    dbconf = Rails.configuration.database_configuration[Rails.env]
    system "psql #{dbconf["database"]} -h #{dbconf["host"]} -c \"#{csv_sql}\" > #{path}"
  end
end
