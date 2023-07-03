#encoding: utf-8
class Place < ApplicationRecord
  acts_as_flaggable
  include ActsAsElasticModel
  # include ActsAsUUIDable
  before_validation :set_uuid
  def set_uuid
    self.uuid ||= SecureRandom.uuid
    self.uuid = uuid.downcase
    true
  end

  has_ancestry orphan_strategy: :adopt

  belongs_to :user
  belongs_to :check_list, :dependent => :destroy
  belongs_to :source
  has_many :check_lists, :dependent => :destroy
  has_many :listed_taxa
  has_many :taxa, :through => :listed_taxa
  has_many :taxon_links, :dependent => :delete_all
  has_many :guides, :dependent => :nullify
  has_many :projects, :dependent => :nullify, :inverse_of => :place
  has_many :trips, :dependent => :nullify, :inverse_of => :place
  has_many :sites, :dependent => :nullify, :inverse_of => :place
  has_many :places_sites, dependent: :destroy
  has_many :place_taxon_names, :dependent => :delete_all, :inverse_of => :place
  has_many :taxon_names, :through => :place_taxon_names
  has_many :users, :inverse_of => :place, :dependent => :nullify
  has_many :search_users, inverse_of: :search_place, dependent: :nullify, class_name: "User"
  # do not destroy observations_places. That will happen
  # in update_observations_places, from a callback in place_geometry
  has_many :observations_places
  has_many :taxon_name_priorities, dependent: :nullify
  has_one :place_geometry, dependent: :destroy, inverse_of: :place
  has_one :place_geometry_without_geom, -> { select(PlaceGeometry.column_names - ['geom']) }, :class_name => 'PlaceGeometry'
  
  before_save :calculate_bbox_area, :set_display_name
  after_save :check_default_check_list
  after_save :reindex_projects_later, if: Proc.new { |place| place.ancestry_changed? }
  after_destroy :destroy_project_rules

  validates_presence_of :latitude, :longitude
  validates_numericality_of :latitude,
                            allow_blank: true,
                            less_than_or_equal_to: 90,
                            greater_than_or_equal_to: -90,
                            unless: :updating_bbox
  validates_numericality_of :longitude,
                            allow_blank: true,
                            less_than_or_equal_to: 180,
                            greater_than_or_equal_to: -180,
                            unless: :updating_bbox
  validates_length_of :name, :within => 2..500, 
    :message => "must be between 2 and 500 characters"
  validates_uniqueness_of :name, :scope => :ancestry, :unless => Proc.new {|p| p.ancestry.blank?}
  validate :validate_parent_is_not_self
  validate :validate_name_does_not_start_with_a_number
  validate :custom_errors
  validates :place_geometry, presence: true, on: :create

  has_subscribers :to => {
    :observations => {:notification => "new_observations", :include_owner => false}
  }

  preference :check_lists, :boolean, :default => true

  extend FriendlyId
  friendly_id :name, :use => [ :slugged, :finders ], :reserved_words => PlacesController.action_methods.to_a

  requires_privilege :organizer,
    if: Proc.new {|place| place.user && !place.user.is_curator? && !place.user.is_admin?},
    on: :create
  
  def normalize_friendly_id( string )
    super_candidate = super(string)
    candidate = display_name.to_s.split(',').first.parameterize
    candidate = super_candidate if candidate.blank? || candidate == super_candidate
    if candidate.to_i > 0
      candidate = string.gsub( /[^\p{Word}0-9\-_]+/, "-" ).downcase
    end
    if Place.where(:slug => candidate).exists? && !display_name.blank?
      candidate = display_name.parameterize
    end
    candidate
  end

  def should_generate_new_friendly_id?
    name_changed?
  end

  attr_accessor :html
  attr_accessor :updating_bbox

  FLICKR_PLACE_TYPES = ActiveSupport::OrderedHash.new
  FLICKR_PLACE_TYPES[:country]   = 12
  FLICKR_PLACE_TYPES[:region]    = 8 # Flickr regions are equiv to GeoPlanet "states", at least in the US
  FLICKR_PLACE_TYPES[:county]    = 9
  FLICKR_PLACE_TYPES[:locality]  = 7 # Flickr localities => GeoPlanet towns
  # GeoPlanet was a place API offered by Yahoo early in iNat's existence, but
  # they removed it some time around 2016. We still have places with GeoPlanet
  # place type codes, hence these constants
  REJECTED_GEO_PLANET_PLACE_TYPE_CODES = [
    1,    # Building
    3,    # Nearby Building
    11,   # Postal Code
    22,   # Suburb
    23,   # Sports Team
    31,   # Time Zone
    32    # Nearby Intersection
  ]
  GEO_PLANET_PLACE_TYPES = {
    0 => 'Undefined',
    1 => 'Building',
    2 => 'Street Segment',
    3 => 'Nearby Building',
    5 => 'Intersection',
    6 => 'Street',
    7 => 'Town',
    8 => 'State',
    9 => 'County',
    10 => 'Local Administrative Area',
    11 => 'Postal Code',
    12 => 'Country',
    13 => 'Island',
    14 => 'Airport',
    15 => 'Drainage',
    16 => 'Land Feature',
    17 => 'Miscellaneous',
    18 => 'Nationality',
    19 => 'Supername',
    20 => 'Point of Interest',
    21 => 'Region',
    22 => 'Suburb',
    23 => 'Sports Team',
    24 => 'Colloquial',
    25 => 'Zone',
    26 => 'Historical State',
    27 => 'Historical County',
    29 => 'Continent',
    31 => 'Time Zone',
    32 => 'Nearby Intersection',
    33 => 'Estate',
    35 => 'Historical Town',
    36 => 'Aggregate'
  }
  GEO_PLANET_PLACE_TYPE_CODES = GEO_PLANET_PLACE_TYPES.invert
  INAT_PLACE_TYPES = {
    100 => 'Open Space',
    101 => 'Territory',
    102 => 'District',
    103 => 'Province'
  }
  GADM_PLACE_TYPES = {
    1000 => 'Municipality',
    1001 => 'Parish',
    # As far as I can tell, this is not actually present in GADM, but people
    # have started using it so I guess we have to keep it... whatever it means.
    # ~~kueda 20200409
    1002 => 'Department Segment',
    1003 => 'City Building',
    1004 => 'Commune',
    1005 => 'Governorate',
    1006 => 'Prefecture',
    1007 => 'Canton',
    1008 => 'Republic',
    1009 => 'Division',
    1010 => 'Subdivision',
    1011 => 'Village block',
    1012 => 'Sum',
    1013 => 'Unknown',
    1014 => 'Shire',
    1015 => 'Prefecture City',
    1016 => 'Regency',
    1017 => 'Constituency',
    1018 => 'Local Authority',
    1019 => 'Poblacion',
    1020 => 'Delegation'
  }
  PLACE_TYPES = GEO_PLANET_PLACE_TYPES.merge(INAT_PLACE_TYPES).merge(GADM_PLACE_TYPES).delete_if do |k,v|
    Place::REJECTED_GEO_PLANET_PLACE_TYPE_CODES.include?(k)
  end

  PLACE_TYPE_CODES = PLACE_TYPES.invert
  PLACE_TYPES.each do |code, type|
    PLACE_TYPE_CODES[type.downcase] = code
    const_set type.upcase.gsub(/\W/, '_'), code
    scope type.pluralize.underscore.to_sym, -> { where("place_type = ?", code) }
  end

  CONTINENT_LEVEL = -10
  REGION_LEVEL = -5
  COUNTRY_LEVEL = 0
  STATE_LEVEL = 10
  COUNTY_LEVEL = 20
  TOWN_LEVEL = 30
  PARK_LEVEL = 100
  ADMIN_LEVELS = [CONTINENT_LEVEL, REGION_LEVEL, COUNTRY_LEVEL, STATE_LEVEL, COUNTY_LEVEL, TOWN_LEVEL, PARK_LEVEL]

  scope :dbsearch, lambda {|q| where("name LIKE ?", "%#{q}%")}
  
  scope :containing_lat_lng, lambda {|lat, lng|
    joins(:place_geometry).where("ST_Intersects(place_geometries.geom, ST_Point(?, ?))", lng, lat)
  }

  scope :containing_lat_lng_as_geography, lambda {|lat, lng|
    joins(:place_geometry).where("ST_Intersects(place_geometries.geom::geography, ST_Point(?, ?))", lng, lat)
  }

  scope :bbox_containing_lat_lng, lambda {|lat, lng|
    where(
      "(swlng > 0 AND nelng < 0 AND swlat <= ? AND nelat >= ? AND (swlng <= ? OR nelng >= ?)) " +
      "OR (swlng * nelng >= 0 AND swlat <= ? AND nelat >= ? AND swlng <= ? AND nelng >= ?)", 
      lat, lat, lng, lng,
      lat, lat, lng, lng
    )
  }
  
  scope :containing_bbox, lambda {|swlat, swlng, nelat, nelng|
    where("swlat <= ? AND nelat >= ? AND swlng <= ? AND nelng >= ?", swlat, nelat, swlng, nelng)
  }
  
  # This can be very expensive.  Use sparingly, or scoped.
  scope :intersecting_taxon, lambda{|taxon|
    taxon_id = taxon.is_a?(Taxon) ? taxon.id : taxon.to_i
    joins("JOIN place_geometries ON place_geometries.place_id = places.id").
    joins("JOIN taxon_ranges ON taxon_ranges.taxon_id = #{taxon_id}").
    where("ST_Intersects(place_geometries.geom, taxon_ranges.geom)")
  }

  scope :including_observation, lambda{ |obs_id|
    obs_id = obs_id.is_a?(Observation) ? obs_id.id : obs_id.to_i
    joins("JOIN place_geometries pg ON pg.place_id = places.id").
    joins("JOIN observations o ON ST_Intersects(pg.geom, o.private_geom)").
    where("o.id = #{ obs_id }")
  }

  scope :listing_taxon, lambda {|taxon|
    taxon_id = if taxon.is_a?(Taxon)
      taxon
    elsif taxon.to_i == 0
      Taxon.single_taxon_for_name(taxon)
    else
      taxon
    end
    select("DISTINCT places.id, places.*").
    joins("LEFT OUTER JOIN listed_taxa ON listed_taxa.place_id = places.id").
    where("listed_taxa.taxon_id = ?", taxon_id)
  }

  scope :with_establishment_means, lambda {|establishment_means|
    scope = joins("LEFT OUTER JOIN listed_taxa ON listed_taxa.place_id = places.id")
    case establishment_means
    when ListedTaxon::NATIVE
      scope.where("listed_taxa.establishment_means IN (?)", ListedTaxon::NATIVE_EQUIVALENTS)
    when ListedTaxon::INTRODUCED
      scope.where("listed_taxa.establishment_means IN (?)", ListedTaxon::INTRODUCED_EQUIVALENTS)
    else
      scope.where("listed_taxa.establishment_means = ?", establishment_means)
    end
  }
  
  scope :place_type, lambda {|place_type|
    place_type = PLACE_TYPE_CODES[place_type] if place_type.is_a?(String) && place_type.to_i == 0
    place_type = place_type.to_i
    where(:place_type => place_type)
  }
  
  scope :place_types, lambda {|place_types|
    place_types = place_types.map do |place_type|
      place_type = PLACE_TYPE_CODES[place_type] if place_type.is_a?(String) && place_type.to_i == 0
      place_type.to_i
    end
    where("place_type IN (?)", place_types)
  }

  scope :with_geom, -> { joins(:place_geometry).where("place_geometries.id IS NOT NULL") }
  scope :with_check_list, -> { joins(:check_list).where("lists.id IS NOT NULL") }
  scope :straddles_date_line, -> { where("swlng > 180 OR swlng < -180 OR nelng > 180 OR nelng < -180 OR (swlng > 0 AND nelng < 0)") }

  def self.north_america
    @@north_america ||= Place.where(name: "North America").
      order(bbox_area: :desc).limit(1).first
  end

  def to_s
    "<Place id: #{id}, name: #{name}, admin_level: #{admin_level}, " + 
    "place_type_name: #{place_type_name}, lat: #{latitude}, " +
    "lng: #{longitude}, parent_id: #{parent_id}>"
  end
  
  def validate_parent_is_not_self
    if !id.blank? && id == ancestor_ids.last
      errors.add(:parent_id, "cannot be the same as the place itself")
    end
  end

  def validate_name_does_not_start_with_a_number
    if name.to_i > 0
      errors.add(:name, "cannot start with a number")
    end
  end
  
  def place_type_name
    PLACE_TYPES[place_type]
  end
  
  def place_type_name=(name)
    self.place_type = PLACE_TYPE_CODES[name]
  end
  
  # Wrap the attr call to set it if unset (or if :reload => true)
  def display_name(options = {})
    return read_attribute(:display_name) unless read_attribute(:display_name).blank? || options[:reload]
    
    ancestor_names = ancestors.reverse.select do |a|
      [Place::TOWN_LEVEL, Place::STATE_LEVEL, Place::COUNTRY_LEVEL].include?(a.admin_level)
    end.map do |a|
      a.code.blank? ? a.name : a.code.split('-').last
    end.compact
    
    new_name = if self.admin_level == COUNTY_LEVEL && ancestor_names.include?('US')
      "#{self.name} County"
    else
      self.name
    end
    new_display_name = [new_name, *ancestor_names].join(', ')
    unless new_record?
      Place.where(id: id).update_all(display_name: new_display_name)
    end
    
    new_display_name
  end

  def set_display_name
    return true unless ancestry_changed?
    display_name(:reload => true)
    true
  end

  def wikipedia_name
    if [TOWN_LEVEL, COUNTY_LEVEL].include?(admin_level)
      display_name.gsub(', US', '')
    else
      name
    end
  end

  # Wrapper around a common translation that prevents a potentially serious
  # side-effect of the name not converting to an underscored version properly.
  # If that fails and we try to return I18n.t( "places_name." ), we'll actually
  # return a rather large hash instead of a string
  def translated_name( locale = I18n.locale, options = {} )
    default = options.delete(:default) || name
    name_key = name.parameterize.underscore
    name_key = name.strip.gsub( /\s+/, "_" ) if name_key.blank?
    t_name = I18n.t( "places_name.#{name_key}", locale: locale, default: nil )
    return default if t_name.blank? || !t_name.is_a?( String )
    t_name
  end
  
  # Calculate and cache the bbox area for place area size queries
  def calculate_bbox_area
    if swlat && swlng && nelat && nelng && (swlat_changed? || swlng_changed? || nelat_changed? || nelng_changed?)
      height = nelat - swlat
      width = straddles_date_line? ? (180 - swlng) + (180 - nelng*-1) : nelng - swlng
      self.bbox_area = width * height
    end
    true
  end
  
  def straddles_date_line?
    return true if self.swlng.to_f.abs > 180 || self.nelng.to_f.abs > 180
    self.swlng.to_f > 0 && self.nelng.to_f < 0
  end

  def editable_by?(user)
    return false if user.blank?
    return true if user.is_admin?
    return true if user.is_curator? && admin_level.nil?
    return true if self.user_id == user.id
    return false if !admin_level.nil? && !user.is_admin?
    false
  end
  
  # Create a CheckList associated with this place
  def check_default_check_list
    if too_big_for_check_list? && !prefers_check_lists && check_list
      delay(:priority => USER_INTEGRITY_PRIORITY).remove_default_check_list
    end
    if too_big_for_check_list?
      self.prefers_check_lists = false
    end
    if prefers_check_lists && check_list.blank?
      self.create_check_list(:place => self)
      save(:validate => false)
      unless check_list.valid?
        Rails.logger.info "[INFO] Failed to create a default check list on " + 
          "creation of #{self}: " + 
          check_list.errors.full_messages.join(', ')
      end
    end
    true
  end

  def reindex_projects_later
    Project.elastic_index!( scope: Project.in_place( id ), delay: true )
    true
  end

  def destroy_project_rules
    ProjectObservationRule.where(
      operand_type: "Place",
      operand_id: id
    ).destroy_all
  end

  def too_big_for_check_list?
    # 9000 is about the size of Africa, debeatable if checklists for places
    # bigger than that are actually useful
    bbox_area.to_f > 9000 && !user_id.blank?
  end

  def remove_default_check_list
    return unless check_list
    check_list.listed_taxa.delete_all
    check_list.destroy
  end

  def validate_with_geom( geom, max_area_km2: nil, max_observation_count: nil )
    if geom.is_a?( GeoRuby::SimpleFeatures::Geometry )
      georuby_geom = geom
      geom = RGeo::WKRep::WKBParser.new.parse( georuby_geom.as_wkb ) rescue nil
    end
    if geom.blank?
      # This probably means GeoRuby parsed some polygons but RGeo didn't think
      # they looked like a multipolygon, possibly because of overlapping
      # polygons or other problems
      add_custom_error( :base, "Failed to import a boundary. Check for slivers, overlapping polygons, and other geometry issues." )
      return false
    end

    if max_observation_count
      observation_count = Observation.where("ST_Intersects(private_geom, ST_GeomFromEWKT(?))", geom.as_text).count
      if observation_count > max_observation_count
        add_custom_error(:place_geometry, :contains_too_many_observations)
        return false
      end
    end

    if max_area_km2
      area_km2 = PlaceGeometry.area_km2( geom )
      if area_km2 > max_area_km2
        add_custom_error( :place_geometry, :is_too_large_to_import )
        return false
      end
    end

    true
  end
  
  # Update the associated place_geometry or create a new one
  def save_geom( geom, max_area_km2: nil, max_observation_count: nil, **other_attrs )
    if geom.is_a?( GeoRuby::SimpleFeatures::Geometry )
      georuby_geom = geom
      geom = RGeo::WKRep::WKBParser.new.parse( georuby_geom.as_wkb ) rescue nil
    end

    return unless validate_with_geom( geom, max_area_km2: max_area_km2, max_observation_count: max_observation_count )

    build_place_geometry unless place_geometry
    begin
      if place_geometry.update( other_attrs.merge( geom: geom ) )
        update( points_from_geom( geom ).merge( updating_bbox: true ) )
      end
    rescue ActiveRecord::StatementInvalid, ActiveRecord::RecordInvalid => e
      Rails.logger.error "[ERROR] \tCouldn't save #{self.place_geometry}: #{e.message[0..200]}"
      if e.message =~ /TopologyException/
        add_custom_error( :base, e.message[/TopologyException: (.+)/, 1] )
      else
        add_custom_error( :base, "Boundary did not save: #{e.message[0..200]}" )
      end
    end
  end
  
  # Appends a geom instead of replacing it
  def append_geom(geom, other_attrs = {})
    if geom.is_a?(GeoRuby::SimpleFeatures::Geometry)
      geom = RGeo::WKRep::WKBParser.new.parse(geom.as_wkb) rescue nil
    end
    new_geom = geom
    self.place_geometry.reload
    if place_geometry && !place_geometry.geom.nil?
      union = place_geometry.geom.union(new_geom)
      new_geom = if union.geometry_type == ::RGeo::Feature::MultiPolygon
        union
      else
        f = place_geometry.geom.factory
        f.multi_polygon([union])
      end
    end
    self.save_geom(new_geom, other_attrs)
  end

  def points_from_geom(geom)
    { latitude: geom.centroid.y, swlat: geom.envelope.lower_corner.y, nelat: geom.envelope.upper_corner.y }.tap do |h|
      if geom.spans_dateline?
        h[:longitude] = geom.envelope.centroid.x + 180*(geom.envelope.centroid.x > 0 ? -1 : 1)
        h[:swlng] = geom.points.map(&:x).select{|x| x > 0 || x < -180}.min
        h[:nelng] = geom.points.map(&:x).select{|x| x < 0 || x > 180}.max
      else
        h[:longitude] = geom.centroid.x
        h[:swlng] = geom.envelope.lower_corner.x
        h[:nelng] = geom.envelope.upper_corner.x
      end
    end
  end
  
  #
  # Import places from a shapefile.  Note that this is optimized for use with
  # a set of adapter methods in PlaceSources.  Note that this always assumes
  # shapefiles have a geographic projection using a NAD83 / WGS84 datum and
  # lat/lon coordinates.
  # Options:
  #   <tt>source</tt>: specify a type of handler for certain shapefiles.  Current options are 'census', 'esriworld', and 'cpad'
  #   <tt>test</tt>: (boolean) setting this to +true+ will do everything other than saving places and geometries.
  #   <tt>ancestor_place</tt>: (Place) scope searches for exissting records to descendents of this place. Matching will be based on name and place_type
  #   <tt>name_column</tt>: column in shapefile attributes that holds the name of the place
  #   <tt>source_identifier_column</tt>: column in shapefile attributes that holds a unique identifier
  #
  # Examples:
  #   Census:
  #     Place.import_from_shapefile('/Users/kueda/Desktop/tl_2008_06_county/tl_2008_06_county.shp', :place_type => 'county', :source => 'census')
  #
  #   California Protected Areas Database:
  #     Place.import_from_shapefile('/Users/kueda/Desktop/CPAD_March09/Units_Fee_09_longlat.shp', :source => 'cpad')
  #
  def self.import_from_shapefile(shapefile_path, options = {}, &block)
    start_time = Time.now
    num_created = num_updated = 0
    src = options[:source]
    options.delete(:source) unless src.is_a?(Source)
    RGeo::Shapefile::Reader.open( shapefile_path ) do |file|
      file.each do |shp|
        puts "[INFO] Working on shp..."
        new_place = case src
        when 'census'
          PlaceSources.new_place_from_census_shape(shp, options)
        when 'esriworld'
          PlaceSources.new_place_from_esri_world_shape(shp, options)
        when 'cpad'
          PlaceSources.new_place_from_cpad_units_fee(shp, options)
        else
          Place.new_from_shape(shp, options)
        end
        
        unless new_place
          puts "[INFO] \t\tShape couldn't be converted to a place.  Skipping..."
          next
        end
        
        new_place.source_filename = options[:source_filename] || File.basename(shapefile_path)
        new_place.source ||= src if src.is_a?(Source)
          
        puts "[INFO] \t\tMade new place: #{new_place}"
        
        # Try to find an existing place
        existing = nil
        if !new_place.source_filename.blank? && !new_place.source_identifier.blank?
          existing ||= Place.where(source_filename: new_place.source_filename,
            source_identifier: new_place.source_identifier).first
        end
        if !new_place.source_filename.blank? && !new_place.source_name.blank?
          existing ||= Place.where(source_filename: new_place.source_filename,
            source_name: new_place.source_name).first
        end
        if !new_place.source_filename.blank? && !new_place.name.blank?
          existing ||= begin
            Place.where(source_filename: new_place.source_filename).where("lower(name) = ?", new_place.name.downcase).first
          rescue
            new_place.name = new_place.name.force_encoding('ISO-8859-1').encode('UTF-8')
            Place.where(source_filename: new_place.source_filename).where("lower(name) = ?", new_place.name.downcase).first
          end
        end
        if options[:ancestor_place]
          existing ||= options[:ancestor_place].descendants.
            where("lower(name) = ? AND place_type = ?", new_place.name.downcase, new_place.place_type).first
        end
        
        if existing
          puts "[INFO] \t\tFound existing place: #{existing}"
          place = existing
          [:swlat, :swlng, :nelat, :nelng, :source_filename, :source_name, 
              :source_identifier].each do |attr_name|
            place.send("#{attr_name}=", new_place.send(attr_name)) if new_place.send(attr_name)
          end
          num_updated += 1
        else
          place = new_place
          num_created += 1
        end

        if options[:ancestor_place]
          place.parent ||= options[:ancestor_place]
        end

        place.place_type = options[:place_type] unless options[:place_type].blank?
        place.place_type_name = options[:place_type_name] unless options[:place_type_name].blank?
        
        place = if block_given?
          yield place, shp
        else
          place
        end
        begin
          if place && place.valid?
            place.save! unless options[:test]
            puts "[INFO] \t\tSaved place: #{place}, parent: #{place.parent.try(:name)}"
          else
            num_created -= 1
            puts "[ERROR] \tPlace invalid: #{place.errors.full_messages.join(', ')}" if place
            next
          end
        rescue ArgumentError => e
          raise e unless e.message =~ /Cannot transliterate/
          # Pretend it's actually UTF
          place.name.force_encoding( "UTF-8" )
          retry
        rescue => e
          puts "[ERROR] \tError: #{e}"
          next
        end
        
        next if options[:test]
        
        if existing && PlaceGeometry.exists?(
            ["place_id = ? AND updated_at >= ?", existing, start_time.utc])
          puts "[INFO] \t\tAppending to existing geom..."
          place.append_geom(shp.geometry, :source => options[:source])
        else
          puts "[INFO] \t\tAdding geom..."
          place.save_geom(shp.geometry, 
            :source => options[:source],
            :source_filename => place.source_filename,
            :source_name => place.source_name, 
            :source_identifier => place.source_identifier)
        end
        place.place_geometry_without_geom.process_geometry
      end
    end
    
    puts "\n[INFO] Finished importing places.  #{num_created} created, " + 
      "#{num_updated} updated (#{Time.now - start_time}s)"
  end
  
  #
  # Make a new Place from a shapefile shape
  #
  def self.new_from_shape(shape, options = {})
    name_column = options[:name_column] || 'name'
    source_identifier_column = options[:source_identifier_column]
    data = shape.respond_to?(:data) ? shape.data : shape.attributes
    name = options[:name] ||
      data[name_column] ||
      data[name_column.upcase] ||
      data[name_column.capitalize] ||
      data[name_column.downcase]
    source_identifier = data[source_identifier_column] if source_identifier_column
    center = shape.geometry.envelope.respond_to?(:center) ? shape.geometry.envelope : shape.geometry.envelope.centroid
    place = Place.new(options.select{|k,v| Place.instance_methods.include?("#{k}=".to_sym)}.merge(
      :name => name,
      :source_identifier => source_identifier,
      :latitude => center.y,
      :longitude => center.x,
      :swlat => shape.geometry.envelope.lower_corner.y,
      :swlng => shape.geometry.envelope.lower_corner.x,
      :nelat => shape.geometry.envelope.upper_corner.y,
      :nelng => shape.geometry.envelope.upper_corner.x
    ))
    place.build_place_geometry( geom: shape.geometry )
    place
  end
  
  def merge(mergee, options = {})
    # Keep chosen attributes from the mergee
    if keepers = options[:keep]
      keepers =  [options[:keep]] unless keepers.is_a?(Array)
      keepers.each do |attr_name|
        self.send("#{attr_name}=", mergee.send(attr_name))
      end
    end
    
    # Hack!  We want to make sure the updates don't invalidate the place 
    # BEFORE we moving stuff around.  This hackery gets us around the unique 
    # name within a parent validation
    temp_name = self.name
    self.name += '_'
    unless self.valid?
      self.name = temp_name
      return self
    end
    self.name = temp_name
    
    # Move the mergee's listed_taxa to the target's default check list
    mergee.check_lists.each do |cl|
      cl.update( place: self )
      ListedTaxon.where( list_id: cl.id ).update_all( place_id: id )
    end
    if check_list
      ListedTaxon.where( list_id: mergee.check_list_id ).update_all( list_id: check_list_id, place_id: id )
    elsif mergee.check_list && mergee.check_list.listed_taxa.count > 0
      mergee.check_list.update( place_id: id, title: "MERGED #{mergee.check_list.title}")
      ListedTaxon.where( list_id: mergee.check_list_id ).update_all( place_id: id )
    end
    
    # Keep reject geometry if keeper doesn't have one
    if place_geometry_without_geom.nil? && !mergee.place_geometry_without_geom.nil?
      save_geom(mergee.place_geometry.geom)
    end

    mergee.children.each do |child|
      child.parent = self
      unless child.save
        # If there's a problem saving the child, orphan it. Otherwise it will
        # get deleted when the parent is deleted
        child.update(:parent => nil)
      end
    end

    # Add any observations_places from mergee into this place
    # which didn't aleady exist
    Place.connection.execute <<-SQL
      INSERT INTO observations_places (observation_id, place_id)
      SELECT op.observation_id, #{id} FROM observations_places op
      WHERE place_id = #{mergee.id}
      AND NOT EXISTS (
        SELECT observation_id FROM observations_places
        WHERE place_id = #{id} AND observation_id = op.observation_id
      )
    SQL
    # Because of the above, if the mergee had any observations_places
    # those merge queries will fail here and the observations_places will
    # remain associated with mergee. This is good because on mergee destroy,
    # that will trigger Place.update_observations_places(mergee) which
    # will index all the observations that used to be in mergee
    merge_has_many_associations(mergee)
    
    # ensure any loaded associates that had their foreign keys updated in the db aren't hanging around
    mergee.reload
    mergee.destroy
    self.save
    CheckList.where(place_id: id).each do |cl|
      cl.delay(priority: USER_INTEGRITY_PRIORITY,
        unique_hash: { "CheckList::refresh": cl.id }
      ).refresh
    end
    if self.check_list
      self.check_list.delay(priority: USER_INTEGRITY_PRIORITY,
        unique_hash: { "CheckList::refresh": self.check_list.id }
      ).refresh
    end
    self
  end
  
  def bounding_box
    box = [swlat, swlng, nelat, nelng].compact
    box.blank? ? nil : box
  end

  # Note that swlng etc accommodate bounding boxes that cross the dateline,
  # while using ST_Envelope( geom ) does not
  def bounding_box_geojson
    return nil unless bounding_box
    {
      type: "Polygon",
      coordinates: [
        [
          [swlng.to_f, swlat.to_f],
          [swlng.to_f, nelat.to_f],
          [nelng.to_f, nelat.to_f],
          [nelng.to_f, swlat.to_f],
          [swlng.to_f, swlat.to_f]
        ]
      ]
    }
  end

  def bounds
    return @bounds if @bounds
    result = PlaceGeometry.where(place_id: id).select("
      ST_YMIN(geom) min_y, ST_YMAX(geom) max_y,
      ST_XMIN(geom) min_x, ST_XMAX(geom) max_x").first
    return @bounds = nil unless result
    @bounds = {
      min_x: [result.min_x.to_f, -179.9].max,
      min_y: [result.min_y.to_f, -89.9].max,
      max_x: [result.max_x.to_f, 179.9].min,
      max_y: [result.max_y.to_f, 89.9].min
    }
  end

  def contains_lat_lng?(lat, lng)
    PlaceGeometry.exists?([
      "place_id = ? AND " + 
      "ST_Intersects(place_geometries.geom, ST_Point(?, ?))",
      id, lng, lat
    ])
  end
  
  def bbox_contains_lat_lng?(lat, lng)
    return false if lat.blank? || lng.blank?
    return nil unless swlng && swlat && nelat && nelng
    if straddles_date_line?
      lat > swlat && lat < nelat && (lng > swlng || lng < nelng)
    else
      lat > swlat && lat < nelat && lng > swlng && lng < nelng
    end
  end

  def bbox_contains_lat_lng_acc?(lat, lng, acc = nil)
    f = RGeo::Geographic.simple_mercator_factory
    return false unless bounding_box
    bbox = f.polygon(
      f.linear_ring([
        f.point(swlng, swlat),
        f.point(swlng, nelat),
        f.point(nelng, nelat),
        f.point(nelng, swlat),
        f.point(swlng, swlat)
      ])
    ) rescue nil
    return false unless bbox
    pt = f.point(lng,lat)

    # buffer the point to make a circle if accuracy set. Note that the method
    # takes accuracy in meters, not sure if it makes a conversion to degrees
    # with latitude in mind.
    if acc.to_f > 0
      pt = pt.buffer( acc )
      # Buffering becomes irrational when the distance is too much, and rgeo will just return nil
      return false if pt.nil?
    end

    # Note that there's a serious problem here in that it doesn't seem to work
    # with geometries that cross longitude 180. The factory will automatically
    # make a polygon with longitudes that exceed 180, but contains? doesn't
    # seem to work properly. When you use the spherical_factory, it claims
    # contains? isn't defined.
    bbox.contains?(pt)
  end

  def bbox_privately_contains_observation?( o )
    sw = o.private_sw_latlon
    ne = o.private_ne_latlon
    return false unless sw && ne
    bbox_contains_lat_lng?( *sw ) && bbox_contains_lat_lng?( *ne )
  end

  def bbox_publicly_contains_observation?( o )
    sw = o.sw_latlon
    ne = o.ne_latlon
    return false unless sw && ne
    bbox_contains_lat_lng?( *sw ) && bbox_contains_lat_lng?( *ne )
  end

  def kml_url
    geometry ||= place_geometry_without_geom if association( :place_geometry_without_geom ).loaded?
    geometry ||= place_geometry if association( :place_geometry ).loaded?
    geometry ||= PlaceGeometry.without_geom.where( place_id: id ).first
    if geometry.blank?
      "".html_safe
    else
      "#{UrlHelper.place_geometry_url( self, format: 'kml' )}?#{geometry.updated_at.to_i}".html_safe
    end
  end

  def self.guide_cache_key(id)
    "place_guide_#{id}"
  end
  
  def serializable_hash(opts = nil)
    options = opts ? opts.clone : { }
    options[:methods] ||= []
    options[:methods] << :place_type_name
    options[:except] ||= []
    options[:except] += [:source_filename, :delta, :bbox_area]
    super(options)
  end

  def ancestor_place_ids
    return unless ancestry
    ancestry.split("/").map(&:to_i) << id
  end

  def self_and_ancestors
    [ancestors, self].flatten
  end

  def descendant_conditions
    Place.descendant_conditions( self )
  end

  def self_and_descendant_conditions
    ["places.id = ? OR places.ancestry like ? OR places.ancestry = ?", id, "#{ancestry}/#{id}/%", "#{ancestry}/#{id}"] 
  end

  def self_and_ancestor_ids
    [ancestor_ids, id].flatten
  end

  def default_observation_precision
    return nil unless nelat
    f = RGeo::Geographic.simple_mercator_factory
    ne_point = f.point(nelng, nelat)
    center_point = f.point(longitude, latitude)
    center_point.distance(ne_point)
  end

  def add_custom_error(scope, error)
    @custom_errors ||= []
    @custom_errors << [scope, error]
  end

  def custom_errors
    return if @custom_errors.blank?
    @custom_errors.each do |scope, error|
      errors.add(scope, error)
    end
  end

  def clean_geometry
    begin
      Place.connection.execute(
        "UPDATE place_geometries SET geom=cleangeometry(geom) WHERE place_id=#{ id }")
    rescue PG::Error => e
      Rails.logger.error "[ERROR #{Time.now}] #{e}"
      Logstasher.write_exception(e)
    end
  end

  def localized_name
    if admin_level === COUNTRY_LEVEL
      translated_name
    else
      display_name
    end
  end

  def area_km2
    place_geometry&.area_km2
  end

  def self.param_to_array(places)
    if places.is_a?(Place)
      # single places become arrays
      [ places ]
    elsif places.is_a?(Integer)
      # single IDs become an array of instances
      Place.where(id: places)
    elsif places.is_a?(Array) && places.size > 0
      if places.first.is_a?(Place)
        # muliple places need no modification
        places
      elsif places.first.is_a?(Integer)
        # multiple IDs become an array of instances
        Place.where(id: places)
      end
    end
  end

  def self.update_observations_places(place_id)
    return if place_id.blank?
    start_time = Time.now
    # observations from existing denormalized records
    ids = Observation.joins(:observations_places).
      where("observations_places.place_id = ?", place_id).pluck(:id)
    Observation.update_observations_places(ids: ids)
    Observation.elastic_index!(ids: ids, wait_for_index_refresh: true)
    # observations not touched above that are in this place
    ids = Observation.in_place(place_id).where("last_indexed_at < ?", start_time).pluck(:id)
    Observation.update_observations_places(ids: ids)
    Observation.elastic_index!(ids: ids, wait_for_index_refresh: true)
  end

end
