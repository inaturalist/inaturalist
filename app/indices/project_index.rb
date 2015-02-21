ThinkingSphinx::Index.define :project, with: :active_record, delta: ThinkingSphinx::Deltas::DelayedDelta do
  indexes :title
  indexes :description
  # This is super brittle: the sphinx doc identifier here is based on
  # ThinkingSphinx.unique_id_expression, which I can't get to work here, so
  # if the number of indexed models changes this will break.
  has "SELECT projects.id * 12 + 2 AS id, regexp_split_to_table(projects.place_id::text ||
    (CASE WHEN ancestry IS NULL THEN '' ELSE '/' || ancestry END), '/')
    AS place_id FROM projects JOIN places ON place_id = places.id",
    as: :place_ids, source: :query, facet: true, type: :integer, multi: true
end
