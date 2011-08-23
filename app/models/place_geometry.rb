# Stores the geometries of places.  We COULD have had a geometry column in the
# places table, but geometries can get rather large, and loading them into
# memory every time you want to work with a place is expensive.
class PlaceGeometry < ActiveRecord::Base
  belongs_to :place
  named_scope :without_geom, {:select => (column_names - ['geom']).join(', ')}
end
