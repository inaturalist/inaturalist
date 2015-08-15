class WindshaftDenormalizer < Denormalizer

  def self.denormalize
    create_all_tables
    # first insert data for ALL taxa (taxon_id = NULL) for all zoom levels
    zooms.each do |zoom|
      # we only want to hide obscured observations from zoom levels 7
      # and above, where the grid size is roughly smaller than 10km
      obscured_condition = zoom[:level] >= 8 ?
        "AND o.private_latitude IS NULL
         AND o.private_longitude IS NULL" : ""
      psql.execute("DELETE FROM #{ zoom[:table] } WHERE taxon_id IS NULL")
      psql.execute("INSERT INTO #{ zoom[:table] }
        SELECT NULL, #{ envelope_for_seed(zoom[:seed]) }, cnt FROM (
          SELECT NULL, #{ snap_for_seed(zoom[:seed]) } as geom, count(*) as cnt
          FROM observations o
          WHERE o.mappable = true
          #{ obscured_condition }
          GROUP BY #{ snap_for_seed(zoom[:seed]) }) AS seed")

      # next loop through all taxa 10,000 at a time and insert data for each batch
      each_taxon_batch_with_index(10000) do |taxa, index, total_batches|
        Taxon.transaction do
          psql.execute("DELETE FROM #{ zoom[:table] } WHERE taxon_id BETWEEN #{ taxa.first.id } AND #{ taxa.last.id }")
          psql.execute("INSERT INTO #{ zoom[:table] }
            SELECT ancestor_taxon_id, #{ envelope_for_seed(zoom[:seed]) }, cnt FROM (
              SELECT ta.ancestor_taxon_id, #{ snap_for_seed(zoom[:seed]) } as geom, count(*) as cnt
              FROM observations o
              INNER JOIN taxa t ON (o.taxon_id = t.id)
              INNER JOIN taxon_ancestors ta ON (t.id = ta.taxon_id)
              WHERE ta.ancestor_taxon_id BETWEEN #{ taxa.first.id } AND #{ taxa.last.id }
              AND o.mappable = true
              #{ obscured_condition }
              GROUP BY ta.ancestor_taxon_id, #{ snap_for_seed(zoom[:seed]) }) AS seed")
        end
      end
      # free up any removable rows
      psql.execute("VACUUM FULL VERBOSE ANALYZE #{ zoom[:table] }") unless Rails.env.test?
    end

  end

  def self.create_all_tables
    # creating one table for every zoom level
    zooms.each do |zoom|
      unless psql.table_exists?(zoom[:table])
        psql.execute("CREATE TABLE #{ zoom[:table] } (
          taxon_id integer,
          geom geometry,
          count integer NOT NULL)")
        psql.execute("CREATE INDEX index_#{ zoom[:table] }_on_taxon_id ON #{ zoom[:table] } USING btree (taxon_id)")
      end
    end
  end

  def self.destroy_all_tables
    zooms.each do |zoom|
      if psql.table_exists?(zoom[:table])
        psql.execute("DROP TABLE IF EXISTS #{ zoom[:table] }")
      end
    end
  end

  # a very commonly used PostgreSQL statement for generalizing geometries
  # into grids. Often used in SELECT and GROUP BY statements
  def self.snap_for_seed(seed)
    "ST_SnapToGrid(geom, 0+(#{ seed }/2), 75+(#{ seed }/2), #{ seed }, #{ seed })"
  end

  def self.envelope_for_seed(seed)
    "ST_Envelope(ST_GEOMETRYFROMTEXT('LINESTRING('||(st_xmax(geom)-(#{ seed }/2))||' '||(st_ymax(geom)-(#{ seed }/2))||','||(st_xmax(geom)+(#{ seed }/2))||' '||(st_ymax(geom)+(#{ seed }/2))||')',4326))"
  end

  def self.zooms
    [ { seed: 4, level: 2, table: "observation_zooms_2" } ]
  end

end
