class PlaceDenormalizer < Denormalizer

  def self.denormalize
    min = Observation.minimum(:id)
    max = Observation.maximum(:id)
    psql.execute("DELETE FROM observations_places WHERE observation_id < #{ min }") if min
    psql.execute("DELETE FROM observations_places WHERE observation_id > #{ max }") if max
    Observation.update_observations_places
    Observation.update_observations_places(scope: Observation.where("id > #{ max }")) if max
    psql.execute("VACUUM FULL VERBOSE ANALYZE observations_places") unless Rails.env.test?
  end

  def self.truncate
    unless Rails.env.production?
      psql.execute("TRUNCATE TABLE observations_places RESTART IDENTITY")
    end
  end

end
