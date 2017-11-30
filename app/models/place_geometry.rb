# Stores the geometries of places.  We COULD have had a geometry column in the
# places table, but geometries can get rather large, and loading them into
# memory every time you want to work with a place is expensive.
class PlaceGeometry < ActiveRecord::Base
  belongs_to :place
  belongs_to :source
  scope :without_geom, -> { select((column_names - ['geom']).join(', ')) }

  after_save :refresh_place_check_list,
             :dissolve_geometry_if_changed,
             :update_observations_places_later

  after_destroy :update_observations_places_later

  validates_presence_of :geom
  validates_uniqueness_of :place_id
  validate :validate_geometry

  def to_s
    "<PlaceGeometry #{id} place_id: #{place_id}>"
  end

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
      unless new_record?
        self.place.check_list.delay(
          unique_hash: { "CheckList::refresh": self.place.check_list.id },
          queue: "slow", priority: priority).refresh
      end
      self.place.check_list.delay(
        unique_hash: { "CheckList::add_observed_taxa": self.place.check_list.id },
        queue: "slow", priority: priority).add_observed_taxa
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

  def update_observations_places_later
    Place.delay(unique_hash: { "Place::update_observations_places": place_id }).
      update_observations_places(place_id)
  end

  def simplified_geom
    return if !geom
    if !place.bbox_area || place.bbox_area < 0.1
      return geom
    end
    tolerance =
      if place.bbox_area < 1
        0.001
      elsif place.bbox_area < 10
        0.01
      elsif place.bbox_area < 100
        0.017
      elsif place.bbox_area < 500
        0.04
      else
        0.075
      end
    if s = PlaceGeometry.where(id: id).
      select("id, cleangeometry(ST_SimplifyPreserveTopology(geom, #{ tolerance })) as simpl").first.simpl
      return s
    end
    PlaceGeometry.where(id: id).
      select("id, cleangeometry(ST_Buffer(ST_SimplifyPreserveTopology(geom, #{ tolerance }),0)) as simpl").first.simpl
  end

  def bounding_box_geom
    return if !geom
    db_pg = PlaceGeometry.where( id: id ).select( "id, ST_Envelope( geom ) AS bounding_box" ).first
    db_pg.bounding_box if db_pg
  end

  def self.update_observations_places(place_geometry_id)
    if pg = PlaceGeometry.where(id: place_geometry_id).first
      Place.update_observations_places(pg.place_id)
    end
  end

end
