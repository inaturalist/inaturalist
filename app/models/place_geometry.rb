# Stores the geometries of places.  We COULD have had a geometry column in the
# places table, but geometries can get rather large, and loading them into
# memory every time you want to work with a place is expensive.
class PlaceGeometry < ActiveRecord::Base
  belongs_to :place
  belongs_to :source
  scope :without_geom, -> { select((column_names - ['geom']).join(', ')) }
  
  after_save :refresh_place_check_list, :dissolve_geometry_if_changed
  
  validates_presence_of :geom
  validate :validate_geometry
  
  def validate_geometry
    # not sure why this is necessary, but validates_presence_of :geom doesn't always seem to run first
    if geom.blank?
      errors.add(:geom, "cannot be blank")
      return
    end
    if geom.num_points < 4
      errors.add(:geom, " must have more than 3 points")
    end
    
    if geom.detect{|g| g.num_points < 4}
      errors.add(:geom, " has a sub geometry with less than 4 points!")
    end
  end
  
  def refresh_place_check_list
    if place.check_list
      priority = place.user_id.blank? ? INTEGRITY_PRIORITY : USER_PRIORITY
      self.place.check_list.delay(:queue => "slow", :priority => priority).refresh unless new_record?
      self.place.check_list.delay(:queue => "slow", :priority => priority).add_observed_taxa
    end
    true
  end

  def dissolve_geometry_if_changed
    dissolve_geometry if geom_changed?
    true
  end

  def dissolve_geometry
    PlaceGeometry.connection.execute <<-SQL
      UPDATE place_geometries SET geom = reuonioned_geoms.new_geom FROM (
        SELECT ST_Multi(ST_Union(geom)) AS new_geom FROM (
          SELECT (ST_Dump(geom)).geom
          FROM place_geometries
          WHERE id = #{id}
        ) AS expanded_geoms
      ) AS reuonioned_geoms
      WHERE id = #{id}
    SQL
  rescue StandardError => e
    raise unless e.message =~ /conversion failed/
    begin
      Rails.logger.error "[ERROR #{Time.now}] Failed to dissolve for PlaceGeometry #{id}, attempting to simplify: #{e}"
      connection.execute <<-SQL
        UPDATE place_geometries SET geom = reuonioned_geoms.new_geom FROM (
          SELECT ST_Multi(ST_Union(geom)) AS new_geom FROM (
            SELECT ST_SimplifyPreserveTopology((ST_Dump(geom)).geom, 0.0001) AS geom
            FROM place_geometries
            WHERE id = #{id}
          ) AS expanded_geoms
        ) AS reuonioned_geoms
        WHERE id = #{id}
      SQL
    rescue StandardError => e
      raise unless e.message =~ /conversion failed/
      # sucks to lose data, but we really don't want invalid geometries
      Rails.logger.error "[ERROR #{Time.now}] Failed to dissolve for PlaceGeometry #{id}, filtering invalid geoms: #{e}"
      connection.execute <<-SQL
        UPDATE place_geometries SET geom = reuonioned_geoms.new_geom FROM (
          SELECT ST_Multi(ST_Union(geom)) AS new_geom FROM (
            SELECT (ST_Dump(geom)).geom
            FROM place_geometries
            WHERE id = #{id}
          ) AS expanded_geoms
          WHERE ST_IsValid(geom)
        ) AS reuonioned_geoms
        WHERE id = #{id}
      SQL
    end
  end
end
