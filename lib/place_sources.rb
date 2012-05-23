#
# Just a place to shove some useful data & functionality related to place
# sources.  Note that all source shapefiles must be have a geographic
# projection and lat/lon coordinates using a NAD83 / WGS84 datum.  If your
# shapefile has a properly defined projection, converting it is pretty simple
# with OGR (http://gdal.org/ogr/):
#  ogr2ogr -t_srs "+proj=longlat +ellps=GRS80 +datum=NAD83 +no_defs" Units_Fee_09_longlat.shp Units_Fee_09.shp
#
module PlaceSources
  # abbreviated and condensed US Census Legal/Statistical Area Description Codes
  # Several have been mapped to place types that seem right for iNat
  # http://www2.census.gov/geo/tiger/tiger2k/a2kapg.txt
  LSAD = {
    '01' => 'state',                  # state or statistical equivalent of a state	-	state or statistical equivalent of a state
    '03' => 'city',                   # city and borough	City and Borough	legal county equivalent in Alaska
    '04' => 'county',                 # borough	Borough	legal county equivalent in Alaska
    '05' => 'county',                 # census area	Census Area	statistical equivalent of a county in Alaska
    '06' => 'county',                 # county	County	county in 48 states
    '07' => 'county',                 # district	District	legal county equivalent in American Samoa
    '08' => 'city',                   # independent city	city	legal county equivalent in Maryland, Missouri, and Virginia
    '09' => 'city',                   # independent city	-	legal county equivalent in Nevada
    '10' => 'county',                 # island	Island	legal county equivalent in the U.S. Virgin Islands
    '11' => 'county',                 # island	-	legal county equivalent in American Samoa and Marshall Islands 
    '12' => 'county',                 # municipality	Municipality	legal county equivalent in the Northern Mariana Islands and Marshall Islands
    '13' => 'county',                 # municipio	Municipio	legal county equivalent in Puerto Rico
    '14' => 'county',                 # -	-	legal county equivalent (used for District of Columbia and Guam)
    '15' => 'county',                 # parish	Parish	legal county equivalent in Louisiana
    '19' => 'reservation',            # reservation	Reservation	legal county subdivision equivalent in Maine and New York (coextensive with all or part of an American Indian reservation)
    '20' => 'barrio',                 # barrio	barrio	legal county subdivision in Puerto Rico
    '21' => 'borough',                # borough	borough	legal county subdivision in New York; legal county subdivision equivalent in New Jersey and Pennsylvania
    '22' => 'census',                 # census county division	CCD	statistical equivalent of a county subdivision in 				21 States
    '23' => 'census',                 # census subarea	census subarea	statistical equivalent of a county subdivision in Alaska
    '24' => 'census subdistrict',     # census subdistrict	subdistrict	legal county subdivision equivalent in the U.S. Virgin Islands
    '25' => 'city',                   # city	city	legal county subdivision equivalent in 20 States and the District of Columbia
    '26' => 'county',                 # county	county	legal county subdivision in American Samoa
    '27' => 'district',               # district (election magisterial, or municipal, or road)	district	legal county subdivision in Pennsylvania, Virginia, West Virginia, Guam, and Northern Mariana Islands
    '28' => 'district',               # district (assessment, election, magisterial, super-visor's, parish governing authority,or municipal)	-	legal county subdivision in Louisiana, Maryland, Mississippi, Virginia, and West Virginia
    '29' => 'election precinct',      # election precinct	precinct	legal county subdivision in Illinois and Nebraska
    '30' => 'election precinct',      # election precinct	-	legal county subdivision in Illinois and Nebraska
    '31' => 'gore',                   # gore	gore	legal county subdivision in Maine and Vermont
    '32' => 'grant',                  # grant	grant	legal county subdivision in New Hampshire and Vermont
    '33' => 'city',                   # independent city	city	legal county subdivision equivalent in Maryland, Missouri, and Virginia
    '34' => 'city',                   # independent city	-	legal county subdivision equivalent in Nevada
    '35' => 'island',                 # island	-	legal county subdivision in American Samoa 
    '36' => 'location',               # location	location	legal county subdivision in New Hampshire
    '38' => 'location',               # -	-	legal county subdivision equivalent for Arlington County, Virginia
    '39' => 'plantation',             # plantation	plantation	legal county subdivision in Maine
    '40' => 'plantation',             # -	-	legal county subdivision not defined
    '41' => 'barrio-pueblo',          # barrio-pueblo	barrio-pueblo	legal county subdivision in Puerto Rico
    '42' => 'purchase',               # purchase	purchase	legal county subdivision in New Hampshire
    '43' => 'city',                   # town	town	legal county subdivision in eight States; legal county subdivision equivalent in New Jersey, North Carolina, Pennsylvania, and South Dakota
    '44' => 'city',                   # township	township	legal county subdivision in 16 states
    '45' => 'city',                   # township	-	legal county subdivision in Kansas, Minnesota, Nebraska, and North Carolina
    '46' => 'unorganized territory',  # unorganized territory	UT	statistical equivalent of a county subdivision in 10 States
    '47' => 'city',                   # village	village	legal county subdivision equivalent in New Jersey, Ohio, South Dakota, and Wisconsin
    '49' => 'city',                   # charter township	charter township	legal county subdivision in Michigan
    '51' => 'subbarrio',              # subbarrio	subbarrio	legal sub-MCD in Puerto Rico
    '53' => 'city',                   # city and borough	city and borough	incorporated place in Alaska
    '54' => 'city',                   # municipality	municipality	incorporated place in Alaska
    '55' => 'city',                   # comunidad	comunidad 	statistical equivalent of a place in Puerto Rico
    '56' => 'city',                   # borough	borough	incorporated place in Connecticut, New Jersey, and Pennsylvania
    '57' => 'city',                   # census designated place	CDP	statistical equivalent of a place in all 50 states, Guam, Northern Mariana Islands, and the U.S. Virgin Islands
    '58' => 'city',                   # city	city	incorporated place in 49 States (not Hawaii) and District of Columbia
    '59' => 'city',                   # city	-	incorporated place having no legaldescription in three states; place equivalent in five states
    '60' => 'city',                   # town	town	incorporated place in 30 States and the U.S. Virgin Islands
    '61' => 'city',                   # village	village	incorporated place in 20 States and traditional place in American Samoa
    '62' => 'zona urbana',            # zona urbana	zona urbana	statistical equivalent of a place in Puerto Rico
    '65' => 'consolidated city',      # consolidated city	city 	consolidated city in Connecticut, Georgia, and Indiana
    '66' => 'consolidated city',      # consolidated city	-	consolidated city (with unique description or no description)
  }

  # Federal Information Processing Standard (FIPS) state codes
  # Just the 50 states for now.  From http://www.itl.nist.gov/fipspubs/fip5-2.htm
  FIPS_STATES = {
    '01' => 'Alabama',
    '02' => 'Alaska',
    '04' => 'Arizona',
    '05' => 'Arkansas',
    '06' => 'California',
    '08' => 'Colorado',
    '09' => 'Connecticut',
    '10' => 'Delaware',
    '11' => 'District of Columbia',
    '12' => 'Florida',
    '13' => 'Georgia',
    '15' => 'Hawaii',
    '16' => 'Idaho',
    '17' => 'Illinois',
    '18' => 'Indiana',
    '19' => 'Iowa',
    '20' => 'Kansas',
    '21' => 'Kentucky',
    '22' => 'Louisiana',
    '23' => 'Maine',
    '24' => 'Maryland',
    '25' => 'Massachusetts',
    '26' => 'Michigan',
    '27' => 'Minnesota',
    '28' => 'Mississippi',
    '29' => 'Missouri',
    '30' => 'Montana',
    '31' => 'Nebraska',
    '32' => 'Nevada',
    '33' => 'New Hampshire',
    '34' => 'New Jersey',
    '35' => 'New Mexico',
    '36' => 'New York',
    '37' => 'North Carolina',
    '38' => 'North Dakota',
    '39' => 'Ohio',
    '40' => 'Oklahoma',
    '41' => 'Oregon',
    '42' => 'Pennsylvania',
    '44' => 'Rhode Island',
    '45' => 'South Carolina',
    '46' => 'South Dakota',
    '47' => 'Tennessee',
    '48' => 'Texas',
    '49' => 'Utah',
    '50' => 'Vermont',
    '51' => 'Virginia',
    '53' => 'Washington',
    '54' => 'West Virginia',
    '55' => 'Wisconsin',
    '56' => 'Wyoming'
  }
  
  FIPS_STATE_CODES = {
    '01' => 'AL',
    '02' => 'AK',
    '04' => 'AZ',
    '05' => 'AR',
    '06' => 'CA',
    '08' => 'CO',
    '09' => 'CT',
    '10' => 'DE',
    '11' => 'DC',
    '12' => 'FL',
    '13' => 'GA',
    '15' => 'HI',
    '16' => 'ID',
    '17' => 'IL',
    '18' => 'IN',
    '19' => 'IA',
    '20' => 'KS',
    '21' => 'KY',
    '22' => 'LA',
    '23' => 'ME',
    '24' => 'MD',
    '25' => 'MA',
    '26' => 'MI',
    '27' => 'MD',
    '28' => 'MS',
    '29' => 'MO',
    '30' => 'MT',
    '31' => 'NE',
    '32' => 'NV',
    '33' => 'NH',
    '34' => 'NJ',
    '35' => 'NM',
    '36' => 'NY',
    '37' => 'NC',
    '38' => 'ND',
    '39' => 'OH',
    '40' => 'OK',
    '41' => 'OR',
    '42' => 'PA',
    '44' => 'RI',
    '45' => 'SC',
    '46' => 'SD',
    '47' => 'TN',
    '48' => 'TX',
    '49' => 'UT',
    '50' => 'VT',
    '51' => 'VA',
    '53' => 'WA',
    '54' => 'WV',
    '55' => 'WI',
    '56' => 'WY'
  }
  
  #
  # We use the state, county, and place census shapefiles, all of which can be
  # obtained from http://www2.census.gov/cgi-bin/shapefiles/national-files
  #
  def self.new_place_from_census_shape(shape, options = {})
    options = options.clone
    geoplanet_type = nil
    name = options[:name] || shape.data['NAME'] || shape.data['NAME10'] || shape.data['NAMELSAD']
    options[:name] = name
    case options[:place_type]
    when 'state'
      geoplanet_query = if FIPS_STATES.values.include?(name)
        "#{name} State, US"
      else
        name
      end
      geoplanet_type = "State"
    when 'county'
      geoplanet_query = "#{name}, #{FIPS_STATE_CODES[shape.data['STATEFP']]}, US"
      geoplanet_type = "County"
    when 'place'
      geoplanet_query = "#{name}, #{FIPS_STATE_CODES[shape.data['STATEFP']]}, US"
      geoplanet_type = "Town,City,Local+Administrative+Area"
    else
      geoplanet_query = "#{name}, US"
    end
    options = {
      :geoplanet_query => geoplanet_query, 
      :geoplanet_options => {:type => geoplanet_type}
    }.merge(options)
    
    # The county files often contain a lot of weird county-like stuff that we 
    # probably don't want...
    if options[:place_type] == 'county'
      return nil unless LSAD[shape.data['LSAD']] == 'county'
    end
    
    place = Place.new_from_shape(shape, options)
    
    # Using FIPS codes for source identifiers.  Note that for counties and places
    # they are ONLY unique whithin their state
    place.source_identifier = case options[:place_type]
    when 'state'
      shape.data['STATEFP']
    when 'county'
      shape.data['COUNTYFP']
    when 'place'
      shape.data['PLACEFP']
    end
    
    place
  end
  
  #
  # ESRI world political boundaries are a pretty commonly used dataset for
  # demos and the like.  You can get a copy from the UNEP GEO Data Portal:
  # http://geodata.grid.unep.ch/ (search for 'boundaries').  Note that this
  # file is of dubious utility, because it tends to not have national
  # boundaries for large nations (like the US) opting instead for state
  # borders, so you might only want to work with extractions (e.g. states of 
  # India).  Might want to write a script that derives national boundaries...
  #
  def self.new_place_from_esri_world_shape(shape, options = {})
    geoplanet_query = "#{shape.data['ADMIN_NAME']}, #{shape.data['FIPS_CNTRY']}"
    options = {
      :geoplanet_query => geoplanet_query,
      :geoplanet_options => {
        :type => "Country,State,Region,County,Prefecture"
      }
    }.merge(options)

    place = Place.new_from_shape(shape, options)
    place.source_identifier = shape.data['FIPS_ADMIN']
    
    # If GeoPlanet does something stupid like thinking Chugoku Prefecture, 
    # Japan is actually a country named China, ditch it.
    if !options[:skip_woeid] && place.geoplanet_response && 
        place.geoplanet_response.country != shape.data['CNTRY_NAME']
      place = nil
    end
    
    place
  end
  
  #
  # CPAD is the California Protected Areas Database, an awesome shapefile of
  # protected parcels from the state assembled by the GreenInfo Network:
  # http://www.calands.org.  Note that the dataset comes projected in
  # California Teale-Albers, which, aside from being projected, uses a
  # completely different coordinate system, so you will need to project it
  # into lat/lon using the NAD83 / WGS 84 datum for use in iNat.  You can do
  # this very easily with OGR (http://gdal.org/ogr/):
  #  ogr2ogr -t_srs "+proj=longlat +ellps=GRS80 +datum=NAD83 +no_defs" Units_Fee_09_longlat.shp Units_Fee_09.shp
  #
  def self.new_place_from_cpad_units_fee(shape, options = {})
    return nil if ['XA', 'No Access'].include?(shape.data['Access'])
    
    # options = {:geoplanet_query => geoplanet_query}.merge(options)
    place = Place.new_from_shape(shape, options.merge(:skip_woeid => true))
    
    name = shape.data['Unit_Name'] || shape.data['UNIT_NAME']
    name.gsub!(/SP$/, 'State Park')
    name.gsub!(/SB$/, 'State Beach')
    name.gsub!(/NP$/, 'National Park')
    name.gsub!(/NM$/, 'National Monument')
    name.gsub!(/NF$/, 'National Forest')
    name.gsub!(/WA$/, 'Wildlife Area')
    place.name = name
    
    unit_id = shape.data['UNIT_ID']
    
    # Sometimes single parks have many units, so we lump them
    place.source_name = name
    place.source_identifier = unit_id.to_i.to_s if unit_id.to_i != 0
    
    puts "[INFO] \t\tTrying to find a unique WOEID from '#{name}, US'..."
    ydn_places = GeoPlanet::Place.search("#{name}, US", :count => 10, 
      :type => "Land+Feature")
    if ydn_places
      ydn_place = ydn_places.find do |ydnp|
        ydnp.name == shape.data['Label_Name'] && ydnp.admin1 == 'California'
      end
      if ydn_place
        puts "[INFO] \t\tFound unique GeoPlanet place: #{ydn_place.name}, #{ydn_place.woeid}, #{ydn_place.placetype}, #{ydn_place.admin2}, #{ydn_place.admin1}, #{ydn_place.country}"
        place.woeid = ydn_place.woeid
      end
    end
    
    # If still no woeid, try to find a parent anyway by looking for the
    # smallest place whose bounding box contains this one's.  This also
    # ignores places with iNat place types, like the "Open Space" type used
    # for CPAD places
    unless place.woeid
      parent = Place.containing_bbox(place.swlat, place.swlng, place.nelat, 
        place.nelng).first(:order => "bbox_area ASC", 
          :conditions => "place_type < 100")
      place.parent = parent if parent
    end
    
    place.place_type = Place::PLACE_TYPE_CODES['Open Space']
    
    place
  end
end
