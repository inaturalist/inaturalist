class PlaceDenormalizer < Denormalizer

  def self.denormalize
    index = 0
    batch_size = 10
    total = Place.count
    total_batches = (total / batch_size).ceil
    Place.select([ :id ]).order('id').find_in_batches(batch_size: batch_size) do |batch|
      index +=1
      Rails.logger.debug "[DEBUG] Processing batch #{ index } of #{ total_batches }"
      Place.transaction do
        # make sure we don't have any more entries than we have taxa. Trim any
        # taxa with ids lower than the current lowest and higher than the
        # current highest
        if index == 1
          psql.execute("DELETE FROM observations_places WHERE place_id < #{ batch.first.id }")
        elsif index == total_batches
          psql.execute("DELETE FROM observations_places WHERE place_id > #{ batch.last.id }")
        end
        # deleting this batch's data in a transaction. This will allow
        # this method to run while users are accessing the data. There
        # should not be any time (other than the first run) where a taxon
        # does not have ancestry information in this table
        psql.execute("DELETE FROM observations_places WHERE place_id BETWEEN #{ batch.first.id } AND #{ batch.last.id }")
        psql.execute("INSERT INTO observations_places (observation_id, place_id)
          SELECT o.id, pg.place_id FROM observations o
          JOIN place_geometries pg ON ST_Intersects(pg.geom, o.private_geom)
          WHERE pg.place_id BETWEEN #{ batch.first.id } AND #{ batch.last.id }")
      end
    end
    psql.execute("VACUUM FULL VERBOSE ANALYZE observations_places") unless Rails.env.test?
  end

  def self.truncate
    unless Rails.env.production?
      psql.execute("TRUNCATE TABLE observations_places RESTART IDENTITY")
    end
  end

  private

  def self.insert_values(values)
    values.each_slice(5000).each do |slice|
      psql.execute("INSERT INTO observations_places (observation_id, place_id) VALUES " +
        slice.collect{ |v| "(#{ v[0] },#{ v[1] })" }.join(",") )
    end
  end

end
