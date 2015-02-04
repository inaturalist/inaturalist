ThinkingSphinx::Index.define :taxon, with: :active_record, delta: ThinkingSphinx::Deltas::DelayedDelta do
  indexes :name
  indexes taxon_names(:name), as: :names
  indexes colors.value, as: :color_values
  has iconic_taxon_id, facet: true, type: :integer
  has colors(:id), as: :colors, facet: true, multi: true, type: :integer
  has is_active, facet: true
  # has listed_taxa(:place_id), as: :places, facet: true, type: :multi
  # has listed_taxa(:list_id), as: :lists, type: :multi
  has created_at, ancestry
  has "REPLACE(ancestry, '/', ',')", as: :ancestors, multi: true, type: :integer
  has listed_taxa(:place_id), as: :places, facet: true, multi: true, source: :query, type: :integer
  has observations_count
end
