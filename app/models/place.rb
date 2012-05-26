class Place < ActiveRecord::Base
  acts_as_tree
  belongs_to :user
  belongs_to :check_list, :dependent => :destroy
  has_many :check_lists, :dependent => :destroy
  has_many :listed_taxa
  has_many :taxa, :through => :listed_taxa
  has_one :place_geometry, :dependent => :destroy
  
  before_save :calculate_bbox_area
  after_create :create_default_check_list
  
  validates_presence_of :latitude, :longitude
  validates_length_of :name, :within => 2..500, 
    :message => "must be between 2 and 500 characters"
  validates_uniqueness_of :name, :scope => :parent_id
  
  has_subscribers :to => {
    :observations => {:notification => "new_observations", :include_owner => false}
  }
  
  # Place to put a GeoPlanet response to avoid re-querying
  attr_accessor :geoplanet_response
  attr_accessor :html
  
  define_index do
    indexes name
    indexes display_name
    has place_type
    
    # HACK: TS doesn't seem to include attributes in the GROUP BY correctly
    # for Postgres when using custom SQL attr definitions.  It may or may not 
    # be fixed in more up-to-date versions, but the issue has been raised: 
    # http://groups.google.com/group/thinking-sphinx/browse_thread/thread/e8397477b201d1e4
    has :latitude, :as => :fake_latitude
    has :longitude, :as => :fake_longitude
    # END HACK
    
    has 'RADIANS(latitude)', :as => :latitude,  :type => :float
    has 'RADIANS(longitude)', :as => :longitude,  :type => :float
    set_property :delta => :delayed
  end
  
  FLICKR_PLACE_TYPES = ActiveSupport::OrderedHash.new
  FLICKR_PLACE_TYPES[:country]   = 12
  FLICKR_PLACE_TYPES[:region]    = 8 # Flickr regions are equiv to GeoPlanet "states", at least in the US
  FLICKR_PLACE_TYPES[:county]    = 9
  FLICKR_PLACE_TYPES[:locality]  = 7 # Flickr localities => GeoPlanet towns
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
    4 => 'Street',
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
    100 => 'Open Space'
  }
  PLACE_TYPES = GEO_PLANET_PLACE_TYPES.merge(INAT_PLACE_TYPES).delete_if do |k,v|
    Place::REJECTED_GEO_PLANET_PLACE_TYPE_CODES.include?(k)
  end
  PLACE_TYPE_CODES = PLACE_TYPES.invert
  
  named_scope :containing_lat_lng, lambda {|lat, lng|
    # {:conditions => ["swlat <= ? AND nelat >= ? AND swlng <= ? AND nelng >= ?", lat, lat, lng, lng]}
    {:joins => :place_geometry, :conditions => ["ST_Intersects(place_geometries.geom, ST_Point(?, ?))", lng, lat]}
  }
  
  named_scope :containing_bbox, lambda {|swlat, swlng, nelat, nelng|
    {:conditions => ["swlat <= ? AND nelat >= ? AND swlng <= ? AND nelng >= ?", swlat, nelat, swlng, nelng]}
  }
  
  # This can be very expensive.  Use sparingly, or scoped.
  named_scope :intersecting_taxon, lambda{|taxon|
    taxon_id = taxon.is_a?(Taxon) ? taxon.id : taxon.to_i
    {
      :joins => 
        "JOIN place_geometries ON place_geometries.place_id = places.id " + 
        "JOIN taxon_ranges ON taxon_ranges.taxon_id = #{taxon_id}",
      :conditions => "ST_Intersects(place_geometries.geom, taxon_ranges.geom)"
    }
  }
  
  named_scope :place_type, lambda{|place_type|
    place_type = PLACE_TYPE_CODES[place_type] if place_type.is_a?(String) && place_type.to_i == 0
    place_type = place_type.to_i
    {:conditions => {:place_type => place_type}}
  }
  
  named_scope :place_types, lambda{|place_types|
    place_types = place_types.map do |place_type|
      place_type = PLACE_TYPE_CODES[place_type] if place_type.is_a?(String) && place_type.to_i == 0
      place_type.to_i
    end
    {:conditions => ["place_type IN (?)", place_types]}
  }
  
  def to_s
    "<Place id: #{id}, name: #{name}, woeid: #{woeid}, " + 
    "place_type_name: #{place_type_name}, lat: #{latitude}, " +
    "lng: #{longitude}, parent_id: #{parent_id}>"
  end
  
  def place_type_name
    PLACE_TYPES[place_type]
  end
  
  def place_type_name=(name)
    self.place_type = PLACE_TYPE_CODES[name]
  end
  
  # Wrap the attr call to set it if unset (or if :reload => true)
  def display_name(options = {})
    return super unless super.blank? || options[:reload]
    
    ancestor_names = self.ancestors.select do |a|
      %w"town state country".include?(PLACE_TYPES[a.place_type].to_s.downcase)
    end.map do |a|
      a.code.blank? ? a.name : a.code.split('-').last
    end.compact
    
    new_name = if self.place_type_name == 'County' && ancestor_names.include?('US')
      "#{self.name} County"
    else
      self.name
    end
    new_display_name = [new_name, *ancestor_names].join(', ')
    unless new_record?
      Place.update_all(["display_name = ?", new_display_name], ["id = ?", id])
    end
    
    new_display_name
  end
  
  def wikipedia_name
    if %w"Town County".include? place_type_name
      display_name.gsub(', US', '')
    else
      name
    end
  end
  
  # Calculate and cache the bbox area for place area size queries
  def calculate_bbox_area
    if self.swlat && self.swlng && self.nelat && self.nelng && 
        (self.swlat_changed? || self.swlng_changed? || self.nelat_changed? || 
          self.nelng_changed?)
      height = self.nelat - self.swlat
      width = if self.straddles_date_line?
        (180 - self.swlng) + (180 - self.nelng*-1)
      else
        self.nelng - self.swlng
      end
      self.bbox_area = width * height
    end
    true
  end
  
  def straddles_date_line?
    self.swlng > 0 && self.nelng < 0
  end
  
  def contains_lat_lng?(lat, lng)
    swlat <= lat && nelat >= lat && swlng <= lng && nelng >= lng
  end
  
  def editable_by?(user)
    return false if user.blank?
    return true if user.is_curator?
    return true if self.user_id == user.id
    return false if %(country state county).include?(place_type_name.to_s.downcase)
    true
  end
  
  # Import a place from Yahoo GeoPlanet using the WOEID (Where On Earth ID)
  def self.import_by_woeid(woeid, options = {})
    if existing = Place.find_by_woeid(woeid)
      return existing
    end
    
    begin
      ydn_place = GeoPlanet::Place.new(woeid.to_i)
    rescue GeoPlanet::NotFound => e
      logger.error "[ERROR] #{e.class}: #{e.message}"
      return nil
    end
    place = Place.new_from_geo_planet(ydn_place)
    place.parent = options[:parent]
    
    unless options[:ignore_ancestors] || ydn_place.ancestors.blank?
      ancestors = []
      logger.debug "[DEBUG] Saving ancestors..."
      ydn_place.ancestors.reverse_each do |ydn_ancestor|
        next if REJECTED_GEO_PLANET_PLACE_TYPE_CODES.include?(
          ydn_ancestor.placetype_code)
        ancestor = Place.import_by_woeid(ydn_ancestor.woeid, 
          :ignore_ancestors => true, :parent => ancestors.last)
        ancestors << ancestor
        logger.debug "[DEBUG] \t\tSaved #{ancestor}."
        place.parent = ancestors.last
      end
    end
    
    place.save
    place
  end
  
  # Make a new Place from a GeoPlanet::Place
  def self.new_from_geo_planet(ydn_place)
    place = Place.new(
      :woeid => ydn_place.woeid,
      :latitude => ydn_place.latitude,
      :longitude => ydn_place.longitude,
      :place_type => ydn_place.placetype_code,
      :name => ydn_place.name
    )
    place.geoplanet_response = ydn_place
    if ydn_place.bounding_box
      place.swlat = ydn_place.bounding_box[0][0]
      place.swlng = ydn_place.bounding_box[0][1]
      place.nelat = ydn_place.bounding_box[1][0]
      place.nelng = ydn_place.bounding_box[1][1]
    end
    
    case ydn_place.placetype
    when 'State'
      place.code = ydn_place.admin1_code
    when 'Country'
      place.code = ydn_place.country_code
    end
    place
  end
  
  # Make a new Place from a flickraw place response
  def self.new_from_flickraw(flickr_place)
    Place.new(
      :woeid => flickr_place.woeid,
      :latitude => flickr_place.latitude,
      :longitude => flickr_place.longitude,
      :place_type => FLICKR_PLACE_TYPES[flickr_place.place_type.downcase.to_sym],
      :name => flickr_place.name,
      :parent => options[:parent]
    )
  end
  
  # Create a CheckList associated with this place
  def create_default_check_list
    self.create_check_list(:place => self)
    save(false)
    unless check_list.valid?
      logger.info "[INFO] Failed to create a default check list on " + 
        "creation of #{self}: " + 
        check_list.errors.full_messages.join(', ')
    end
  end
  
  # Update the associated place_geometry or create a new one
  def save_geom(geom, other_attrs = {})
    other_attrs.merge!(:geom => geom, :place => self)
    
    begin
      if place_geometry
        self.place_geometry.update_attributes(other_attrs)
      else
        pg = PlaceGeometry.create(other_attrs)
        self.place_geometry = pg
      end
      update_bbox_from_geom(geom) if self.place_geometry.valid?
    rescue ActiveRecord::StatementInvalid => e
      puts "[ERROR] \tCouldn't save #{self.place_geometry}: " + 
        e.message[0..200]
    end
  end
  
  # Appends a geom instead of replacing it
  def append_geom(geom, other_attrs = {})
    new_geom = geom
    self.place_geometry.reload
    if self.place_geometry
      new_geom = MultiPolygon.from_geometries(
        self.place_geometry.geom.geometries + geom.geometries)
    end
    self.save_geom(new_geom, other_attrs)
  end
  
  # Update this place's bbox from a geometry.  Note this skips validations, 
  # but explicitly recalculates the bbox area
  def update_bbox_from_geom(geom)
    self.latitude = geom.envelope.center.y
    self.longitude = geom.envelope.center.x
    self.swlat = geom.envelope.lower_corner.y
    self.swlng = geom.envelope.lower_corner.x
    self.nelat = geom.envelope.upper_corner.y
    self.nelng = geom.envelope.upper_corner.x
    calculate_bbox_area
    save(false)
  end
  
  #
  # Import places from a shapefile.  Note that this is optimized for use with
  # a set of adapter methods in PlaceSources.  Note that this always assumes
  # shapefiles have a geographic projection using a NAD83 / WGS84 datum and
  # lat/lon coordinates.
  # Options:
  #   <tt>source</tt>: specify a type of handler for certain shapefiles.  Current options are 'census', 'esriworld', and 'cpad'
  #   <tt>skip_woeid</tt>: (boolean) Whether or not to require that the shape matches a unique WOEID.  This is based querying GeoPlanet for the name of the shape.
  #   <tt>test</tt>: (boolean) setting this to +true+ will do everything other than saving places and geometries.
  #
  # Examples:
  #   Census:
  #     Place.import_from_shapefile('/Users/kueda/Desktop/tl_2008_06_county/tl_2008_06_county.shp', :place_type => 'county', :source => 'census')
  #
  #   California Protected Areas Database:
  #     Place.import_from_shapefile('/Users/kueda/Desktop/CPAD_March09/Units_Fee_09_longlat.shp', :source => 'cpad', :skip_woeid => true)
  #
  def self.import_from_shapefile(shapefile_path, options = {})
    start_time = Time.now
    num_created = num_updated = 0
    GeoRuby::Shp4r::ShpFile.open(shapefile_path).each do |shp|
      puts "[INFO] Working on shp..."
      new_place = case options[:source]
      when 'census'
        PlaceSources.new_place_from_census_shape(shp, options)
      when 'esriworld'
        PlaceSources.new_place_from_esri_world_shape(shp, options)
      when 'cpad'
        puts "[INFO] \tUNIT_ID: #{shp.data['UNIT_ID']}"
        PlaceSources.new_place_from_cpad_units_fee(shp, options)
      else
        Place.new_from_shape(shp, options)
      end
      
      unless new_place
        puts "[INFO] \t\tShape couldn't be converted to a place.  Skipping..."
        next
      end
      
      new_place.source_filename = options[:source_filename] || File.basename(shapefile_path)
        
      puts "[INFO] \t\tMade new place: #{new_place}"
      unless new_place.woeid || options[:skip_woeid]
        puts "[INFO] \t\tCouldn't find a unique woeid. Skipping..."
        next
      end
      
      # Try to find an existing place
      existing = nil
      existing = Place.find_by_woeid(new_place.woeid) if new_place.woeid
      if new_place.source_filename && new_place.source_identifier
        existing ||= Place.first(:conditions => [
          "source_filename = ? AND source_identifier = ?", 
          new_place.source_filename, new_place.source_identifier])
      end
      if new_place.source_filename && new_place.source_name
        existing ||= Place.first(:conditions => [
          "source_filename = ? AND source_name = ?", 
          new_place.source_filename, new_place.source_name])
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
        place = new_place.woeid ? Place.import_by_woeid(new_place.woeid) : new_place
        [:latitude, :longitude, :swlat, :swlng, :nelat, :nelng, :source_filename, :source_name, 
            :source_identifier, :place_type].each do |attr_name|
          place.send("#{attr_name}=", new_place.send(attr_name)) if new_place.send(attr_name)
        end
        num_created += 1
      end
      
      if place.valid?
        place.save unless options[:test]
        puts "[INFO] \t\tSaved place: #{place}"
      else
        puts "[ERROR] \tPlace invalid: #{place.errors.full_messages.join(', ')}"
        next
      end
      
      next if options[:test]
      
      if existing && PlaceGeometry.exists?(
          ["place_id = ? AND updated_at >= ?", existing, start_time.utc])
        puts "[INFO] \t\tAppending to existing geom..."
        place.append_geom(shp.geometry)
      else
        puts "[INFO] \t\tAdding geom..."
        place.save_geom(shp.geometry, 
          :source_filename => place.source_filename,
          :source_name => place.source_name, 
          :source_identifier => place.source_identifier)
      end
    end
    
    puts "\n[INFO] Finished importing places.  #{num_created} created, " + 
      "#{num_updated} updated (#{Time.now - start_time}s)"
  end
  
  #
  # Make a new Place from a shapefile shape
  #
  def self.new_from_shape(shape, options = {})
    place = Place.new(
      :name => options[:name] || shape.data['NAME'] || shape.data['Name'] || shape.data['name'],
      :latitude => shape.geometry.envelope.center.y,
      :longitude => shape.geometry.envelope.center.x,
      :swlat => shape.geometry.envelope.lower_corner.y,
      :swlng => shape.geometry.envelope.lower_corner.x,
      :nelat => shape.geometry.envelope.upper_corner.y,
      :nelng => shape.geometry.envelope.upper_corner.x
    )
    
    unless options[:skip_woeid]
      puts "[INFO] \t\tTrying to find a unique WOEID from " +
        "'#{options[:geoplanet_query] || place.name}'..."
      geoplanet_options = options.delete(:geoplanet_options) || {}
      geoplanet_options[:count] = 2
      ydn_places = GeoPlanet::Place.search(
        options[:geoplanet_query] || place.name, geoplanet_options)
      if ydn_places && ydn_places.size == 1
        puts "[INFO] \t\tFound unique GeoPlanet place: " + 
          [ydn_places.first.name, ydn_places.first.woeid,
           ydn_places.first.placetype, ydn_places.first.admin2,
           ydn_places.first.admin1, ydn_places.first.country].join(', ')
        place.woeid = ydn_places.first.woeid
        place.geoplanet_response = ydn_places.first
      end
    end
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
    additional_taxon_ids = mergee.taxon_ids - self.taxon_ids
    ListedTaxon.update_all(
      ["place_id = ?, list_id = ?", self, self.check_list_id],
      ["place_id = ? AND taxon_id in (?)", mergee, additional_taxon_ids]
    )
    
    # Merge the geometries
    if self.place_geometry && mergee.place_geometry
      append_geom(mergee.place_geometry.geom)
    elsif mergee.place_geometry
      update_geom(mergee.place_geometry.geom)
    end
    
    mergee.destroy
    self.save
    self
  end
  
  def bounding_box
    box = [swlat, swlng, nelat, nelng].compact
    box.blank? ? nil : box
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
    if swlng.to_f > 0 && nelng.to_f < 0
      lat > swlat && lat < nelat && (lng > swlng || lng < nelng)
    else
      lat > swlat && lat < nelat && lng > swlng && lng < nelng
    end
  end
  
  def self.guide_cache_key(id)
    "place_guide_#{id}"
  end
end
