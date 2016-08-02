psql = User.connection

Benchmark.measure{ psql.execute("ALTER TABLE observations ADD new_uuid uuid DEFAULT uuid_generate_v4()") }

Benchmark.measure do
  Observation.select(:id, :uuid).where("uuid IS NOT NULL").find_in_batches(batch_size: 10000) do |batch|
    psql.transaction do
      puts "Batch starting at ID #{batch.first.id} at #{Time.now}"
      batch.each do |o|
        Observation.where(id: o.id).update_all(new_uuid: o.uuid)
      end
    end
  end
end

Benchmark.measure{ psql.execute("ALTER TABLE observations RENAME column uuid TO old_uuid") }
Benchmark.measure{ psql.execute("ALTER TABLE observations RENAME column new_uuid TO uuid") }
Benchmark.measure{ psql.execute("DROP INDEX index_observations_on_uuid") }
Benchmark.measure{ psql.execute("CREATE INDEX index_observations_on_uuid ON observations(uuid)") }

Benchmark.measure{ psql.execute("ALTER TABLE observation_photos ADD new_uuid uuid DEFAULT uuid_generate_v4()") }
Benchmark.measure{ psql.execute("UPDATE observation_photos SET new_uuid=uuid::uuid WHERE uuid IS NOT NULL") }
Benchmark.measure{ psql.execute("ALTER TABLE observation_photos RENAME column uuid TO old_uuid") }
Benchmark.measure{ psql.execute("ALTER TABLE observation_photos RENAME column new_uuid TO uuid") }
Benchmark.measure{ psql.execute("DROP INDEX index_observation_photos_on_uuid") }
Benchmark.measure{ psql.execute("CREATE INDEX index_observation_photos_on_uuid ON observation_photos(uuid)") }
