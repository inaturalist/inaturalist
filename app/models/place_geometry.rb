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

  after_destroy :destroy_observations_places

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
      if self.place.check_list
        unless new_record?
          self.place.check_list.delay(
            unique_hash: { "CheckList::refresh": self.place.check_list.id },
            queue: "slow", priority: priority).refresh
        end
        self.place.check_list.delay(
          unique_hash: { "CheckList::add_observed_taxa": self.place.check_list.id },
          queue: "slow", priority: priority).add_observed_taxa
      end
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

  def destroy_observations_places
    ObservationsPlace.where(place_id: place_id).delete_all
  end

  def update_observations_places_later
    PlaceGeometry.
      delay(unique_hash: { "PlaceGeometry::update_observations_places": id }).
      update_observations_places(id)
  end

  def self.update_observations_places(place_geometry_id)
    if pg = PlaceGeometry.where(id: place_geometry_id).first
      old_scope = Observation.joins(:observations_places).where("observations_places.place_id = ?", pg.place_id)
      Observation.update_observations_places(scope: old_scope)
      Observation.elastic_index!(scope: old_scope)
      scope = Observation.in_place(pg.place_id)
      Observation.update_observations_places(scope: scope)
      Observation.elastic_index!(scope: scope)
    end
  end

end
