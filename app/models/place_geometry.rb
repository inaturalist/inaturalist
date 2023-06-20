# Stores the geometries of places.  We COULD have had a geometry column in the
# places table, but geometries can get rather large, and loading them into
# memory every time you want to work with a place is expensive.
class PlaceGeometry < ApplicationRecord
  belongs_to :place, inverse_of: :place_geometry
  belongs_to :source
  scope :without_geom, -> { select((column_names - ['geom']).join(', ')) }

  after_save :refresh_place_check_list,
             :process_geometry_if_changed,
             :update_observations_places_later,
             :notify_trusting_project_members

  after_destroy :update_observations_places_later

  validates_presence_of :geom
  validates_presence_of :place
  validates_uniqueness_of :place_id, allow_nil: true
  validate :validate_geometry

  def to_s
    "<PlaceGeometry #{id} place_id: #{place_id}>"
  end

  def area_km2
    return unless geom

    self.class.area_km2( geom )
  end

  def self.area_km2( geom )
    connection.query_value sanitize_sql_array( ["SELECT ST_Area(?::geography) / 1000 ^ 2", geom.as_text] )
  end

  def validate_geometry
    # not sure why this is necessary, but validates_presence_of :geom doesn't always seem to run first
    if geom.blank?
      errors.add(:geom, :cannot_be_blank)
      return
    end
    if geom.num_points < 4
      errors.add(:geom, :must_have_more_than_three_points)
    end
    if geom.detect{|g| g.num_points < 4}
      errors.add(:geom, :polygon_with_less_than_four_points)
    end
    if geom.detect{|g| g.points.detect{|pt| pt.x < -180 || pt.x > 180 || pt.y < -90 || pt.y > 90}}
      errors.add(:geom, :invalid_point)
    end
  end

  # During the Rails 5 upgrade, invalid WKT assigned to geom raised this error
  # when the geometry tried to be read. This seems like a problem with RGeo
  # that hasn't been fixed yet, so this is a rough kluge. Alternatively, we
  # could raise something more specific and catch it elsewhere. This might fail
  # a bit silently. ~~kueda 20210702
  def geom
    begin
      super
    rescue NoMethodError => e
      raise e unless e.message =~ /undefined method.*factory/
      errors.add(:geom, "could not be parsed")
      nil
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

  def process_geometry_if_changed
    process_geometry if saved_change_to_geom?
    true
  end

  def process_geometry
    PlaceGeometry.connection.execute <<-SQL
      UPDATE place_geometries SET geom = reuonioned_geoms.new_geom FROM (
        SELECT
          ST_RemoveRepeatedPoints(ST_Multi(ST_Union(ST_MakeValid(geom)))) AS new_geom
        FROM (
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
          SELECT
            ST_RemoveRepeatedPoints(ST_Multi(ST_Union(geom))) AS new_geom
          FROM (
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
          SELECT
            ST_RemoveRepeatedPoints(ST_Multi(ST_Union(geom))) AS new_geom
          FROM (
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
    Place.delay(
      unique_hash: { "Place::update_observations_places": place_id },
      run_at: 5.minutes.from_now,
      queue: "throttled"
    ).update_observations_places( place_id )
  end

  def notify_trusting_project_members
    return true unless saved_change_to_geom?
    Project.
        joins(:project_observation_rules).
        where( "rules.operator = 'observed_in_place?'" ).
        where( "rules.operand_type = 'Place'" ).
        where( "rules.operand_id = ?", place_id ).
        where( project_type: %w(collection umbrella) ).
        find_each do |proj|
      proj.notify_trusting_members_about_changes_later
    end
    true
  end

  def simplified_geom
    # if the geom does not exist, or RGeo thinks the geometry is invalid, return nil
    begin
      return if !geom
    rescue RGeo::Error::InvalidGeometry => e
      return
    end
    if !place.bbox_area || place.bbox_area < 0.1
      # this method is currently only used for indexing places in Elasticsearch.
      # Running the cleangeometry method here helps fix geom validation errors
      # which psql is comfortable with but might cause ES to throw errors
      return PlaceGeometry.where(id: id).
        select("id, cleangeometry(geom) as simpl").first.try(:simpl) rescue nil
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
      select("id, cleangeometry(ST_SimplifyPreserveTopology(geom, #{ tolerance })) as simpl").first.simpl rescue nil
      return s
    end
    PlaceGeometry.where(id: id).
      select("id, cleangeometry(ST_Buffer(ST_SimplifyPreserveTopology(geom, #{ tolerance }),0)) as simpl").first.simpl rescue nil
  end

  def self.update_observations_places(place_geometry_id)
    if pg = PlaceGeometry.where(id: place_geometry_id).first
      Place.update_observations_places(pg.place_id)
    end
  end

end
