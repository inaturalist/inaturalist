# Stores the geometries of places.  We COULD have had a geometry column in the
# places table, but geometries can get rather large, and loading them into
# memory every time you want to work with a place is expensive.
class PlaceGeometry < ActiveRecord::Base
  belongs_to :place
  named_scope :without_geom, {:select => (column_names - ['geom']).join(', ')}
  
  after_save :refresh_place_check_list
  
  validates_presence_of :geom
  validate :validate_geometry
  
  def validate_geometry
    if geom.num_points < 4
      errors.add(:geom, " must have more than 3 points")
    end
    
    if geom.geometries.detect{|g| g.num_points < 4}
      errors.add(:geom, " has a sub geometry with less than 4 points!")
    end
  end
  
  def refresh_place_check_list
    self.place.check_list.send_later(:refresh, :dj_priority => 1) unless new_record?
    self.place.check_list.send_later(:add_observed_taxa, :dj_priority => 1)
    true
  end
end
