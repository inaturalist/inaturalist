ThinkingSphinx::Index.define :observation, with: :active_record, delta: ThinkingSphinx::Deltas::DelayedDelta do
  indexes taxon.taxon_names.name, as: :names
  indexes tags(:name), as: :tags
  indexes :species_guess, sortable: true, as: :species_guess
  indexes :description, as: :description
  indexes :place_guess, as: :place, sortable: true
  indexes user(:login), as: :user, sortable: true
  indexes :observed_on_string, as: :observed_on_string
  indexes :quality_grade
  indexes observation_field_values.value, as: :ofv_values
  indexes observation_field_values.observation_field.name, as: :observation_field_names

  has :user_id
  has :taxon_id

  # Sadly, the following doesn't work, because self_and_ancestors is not an
  # association.  I'm not entirely sure if there's a way to work the ancestry
  # query in as col in a SQL query on observations.  If at some point we
  # need to have the ancestor ids in the Sphinx index, though, we can always
  # add a col to the taxa table holding the ancestor IDs.  Kind of a
  # redundant, and it would slow down moves, but it might be worth it for
  # the snappy searches. --KMU 2009-04-4
  # has taxon.self_and_ancestors(:id), as: :taxon_self_and_ancestors_ids

  has "observation_photos_count > 0", as: :has_photos, type: :boolean
  has "observation_sounds_count > 0", as: :has_sounds, type: :boolean
  has :created_at, type: :timestamp
  has :observed_on, type: :timestamp
  has :iconic_taxon_id
  has :id_please, as: :has_id_please, type: :boolean
  has "latitude IS NOT NULL AND longitude IS NOT NULL",
    as: :has_geo, type: :boolean
  has 'RADIANS(latitude)', as: :latitude,  type: :float
  has 'RADIANS(longitude)', as: :longitude,  type: :float

  # HACK: TS doesn't seem to include attributes in the GROUP BY correctly
  # for Postgres when using custom SQL attr definitions.  It may or may not
  # be fixed in more up-to-date versions, but the issue has been raised:
  # http://groups.google.com/group/thinking-sphinx/browse_thread/thread/e8397477b201d1e4
  has :latitude, as: :fake_latitude
  has :longitude, as: :fake_longitude
  has :observation_photos_count
  has :observation_sounds_count
  has :num_identification_agreements
  has :num_identification_disagreements
  # END HACK

  has "num_identification_agreements > num_identification_disagreements",
    as: :identifications_most_agree, type: :boolean
  has "num_identification_agreements > 0",
    as: :identifications_some_agree, type: :boolean
  has "num_identification_agreements < num_identification_disagreements",
    as: :identifications_most_disagree, type: :boolean
  has project_observations(:project_id), as: :projects
  has observation_field_values(:observation_field_id), as: :observation_fields
end
