ThinkingSphinx::Index.define :place, with: :active_record, delta: ThinkingSphinx::Deltas::DelayedDelta do
  indexes :name
  indexes display_name
  has place_type

  # HACK: TS doesn't seem to include attributes in the GROUP BY correctly
  # for Postgres when using custom SQL attr definitions.  It may or may not
  # be fixed in more up-to-date versions, but the issue has been raised:
  # http://groups.google.com/group/thinking-sphinx/browse_thread/thread/e8397477b201d1e4
  has :latitude, as: :fake_latitude
  has :longitude, as: :fake_longitude
  # END HACK

  # # This is super brittle: the sphinx doc identifier here is based on
  # # ThinkingSphinx.unique_id_expression, which I can't get to work here, so
  # # if the number of indexed models changes this will break.
  # has "SELECT places.id, places.id * 4::INT8 + 1 AS id, regexp_split_to_table(id::text ||
  #   (CASE WHEN ancestry IS NULL THEN '' ELSE '/' || ancestry END), '/')
  #   AS place_ids FROM places", as: :place_ids, source: :query, type: :integer

  has "RADIANS(latitude)", as: :latitude, type: :float
  has "RADIANS(longitude)", as: :longitude, type: :float
end
