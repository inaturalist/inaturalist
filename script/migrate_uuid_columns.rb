psql = User.connection

psql.execute("ALTER TABLE observations ADD new_uuid uuid DEFAULT uuid_generate_v4()")   # new column, no default
psql.execute("UPDATE observations SET new_uuid=uuid::uuid WHERE uuid IS NOT NULL")      # set values
psql.execute("ALTER TABLE observations RENAME column uuid TO old_uuid")                 # swap out old
psql.execute("ALTER TABLE observations RENAME column new_uuid TO uuid")                 # swap in new
psql.execute("DROP INDEX index_observations_on_uuid")                                   # remove old index
psql.execute("CREATE INDEX index_observations_on_uuid ON observations(uuid)")           # create new index


psql.execute("ALTER TABLE observation_photos ADD new_uuid uuid DEFAULT uuid_generate_v4()")   # new column, no default
psql.execute("UPDATE observation_photos SET new_uuid=uuid::uuid WHERE uuid IS NOT NULL")      # set values
psql.execute("ALTER TABLE observation_photos RENAME column uuid TO old_uuid")                 # swap out old
psql.execute("ALTER TABLE observation_photos RENAME column new_uuid TO uuid")                 # swap in new
psql.execute("DROP INDEX index_observation_photos_on_uuid")                                   # remove old index
psql.execute("CREATE INDEX index_observation_photos_on_uuid ON observation_photos(uuid)")     # create new index


