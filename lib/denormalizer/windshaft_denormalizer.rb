class WindshaftDenormalizer < Denormalizer

  def self.denormalize
    create_all_tables
    # first insert data for ALL taxa (taxon_id = NULL) for all zoom levels
    zooms.each do |zoom|
      psql.execute("DELETE FROM #{ zoom[:table] } WHERE taxon_id IS NULL")
      psql.execute("INSERT INTO #{ zoom[:table] }
        SELECT NULL, #{ snap_for_seed(zoom[:seed]) }, count(*)
        FROM observations o
        GROUP BY #{ snap_for_seed(zoom[:seed]) }")
    end

    # next loop through all taxa 10,000 at a time and insert data for
    # each batch at all zoom levels
    each_taxon_batch_with_index(10000) do |taxa, index, total_batches|
      zooms.each do |zoom|
        Taxon.transaction do
          psql.execute("DELETE FROM #{ zoom[:table] } WHERE taxon_id BETWEEN #{ taxa.first.id } AND #{ taxa.last.id }")
          psql.execute("INSERT INTO #{ zoom[:table] }
            SELECT ta.ancestor_taxon_id, #{ snap_for_seed(zoom[:seed]) }, count(*)
            FROM observations o
            INNER JOIN taxa t ON (o.taxon_id = t.id)
            INNER JOIN taxon_ancestors ta ON (t.id = ta.taxon_id)
            WHERE ta.ancestor_taxon_id BETWEEN #{ taxa.first.id } AND #{ taxa.last.id }
            GROUP BY ta.ancestor_taxon_id, #{ snap_for_seed(zoom[:seed]) }")
        end
      end
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

  def self.zooms
    [ { seed: 4, table: "observation_zooms_2" },
      { seed: 2, table: "observation_zooms_3" },
      { seed: 0.99, table: "observation_zooms_4" },
      { seed: 0.5, table: "observation_zooms_5" },
      { seed: 0.25, table: "observation_zooms_6" },
      { seed: 0.125, table: "observation_zooms_7" },
      { seed: 0.0625, table: "observation_zooms_8" },
      { seed: 0.03125, table: "observation_zooms_9" },
      { seed: 0.015625, table: "observation_zooms_10" },
      { seed: 0.0078125, table: "observation_zooms_11" },
      { seed: 0.00390625, table: "observation_zooms_12" } ]
  end

end
