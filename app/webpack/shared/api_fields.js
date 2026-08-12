export const TAXON_FIELDS = {
  id: true,
  name: true,
  rank: true,
  rank_level: true,
  iconic_taxon_name: true,
  preferred_common_name: true,
  preferred_common_names: true,
  is_active: true,
  extinct: true,
  ancestor_ids: true,
  default_photo: {
    url: true
  }
};

export const SPECIES_COUNTS_FIELDS = {
  count: true,
  taxon: TAXON_FIELDS
};

export const USER_FIELDS = {
  id: true,
  login: true,
  name: true,
  icon_url: true
};

export const OBSERVATION_FIELDS = {
  id: true,
  observed_on: true,
  non_owner_ids: true,
  comments: true,
  faves: true,
  created_at_details: "all",
  created_at: true,
  created_time_zone: true,
  observed_on_details: "all",
  time_observed_at: true,
  observed_time_zone: true,
  place_guess: true,
  latitude: true,
  longitude: true,
  identifications: {
    current: true
  },
  quality_grade: true,
  photos: {
    id: true,
    uuid: true,
    url: true,
    license_code: true,
    original_dimensions: "all"
  },
  taxon: {
    id: true,
    uuid: true,
    name: true,
    iconic_taxon_name: true,
    is_active: true,
    preferred_common_name: true,
    preferred_common_names: true,
    rank: true,
    rank_level: true
  },
  user: USER_FIELDS
};
