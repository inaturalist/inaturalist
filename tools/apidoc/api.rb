require "rubygems"
require 'trollop'
require "haml"
require "active_support"
require "active_support/core_ext/string/inflections"

opts = Trollop::options do
    banner <<-EOS
Generate iNaturalist API HTML docs.

Usage:

  ruby tools/apidoc/api.rb > path/to/your.html
EOS
end

class Api
  attr_accessor :name, :api_methods
  
  def initialize(name)
    @name = name
    @api_methods = []
  end
  
  def desc(d = nil)
    d ? @desc = d : @desc
  end
  
  def get(path, options = {}, &block)
    options[:method] = :get
    m = ApiMethod.new(path, options)
    m.instance_eval(&block)
    @api_methods << m
  end

  def post(path, options = {}, &block)
    options[:method] = :post
    m = ApiMethod.new(path, options)
    m.instance_eval(&block)
    @api_methods << m
  end

  def put(path, options = {}, &block)
    options[:method] = :put
    m = ApiMethod.new(path, options)
    m.instance_eval(&block)
    @api_methods << m
  end

  def delete(path, options = {}, &block)
    options[:method] = :delete
    m = ApiMethod.new(path, options)
    m.instance_eval(&block)
    @api_methods << m
  end
end

class ApiMethod
  attr_accessor :path, :desc, :formats, :examples, :method, :params, :auth_required
  
  def initialize(path, options = {})
    @path = path
    @method = options[:method]
    @formats = []
    @params = []
    @examples = []
    @auth_required = options[:auth_required]
  end
  
  def desc(d = nil)
    d ? @desc = d : @desc
  end
  
  def formats(formats = nil)
    formats ? @formats = formats : @formats
  end
  
  def example(&block)
    if block_given?
      example = ApiMethodExample.new
      example.instance_eval(&block)
      @examples << example
    else
      @examples.first
    end
  end
  
  def param(name, &block)
    p = ApiMethodParam.new(name)
    p.instance_eval(&block)
    @params << p
  end

  def title
    "#{@method.to_s.upcase} #{@path}"
  end
end

class ApiMethodExample
  attr_accessor :request, :response
  
  def request(r = nil)
    r ? @request = r : @request
  end
  
  def response(r = nil)
    r ? @response = r : @response
  end
end

class ApiMethodParam
  attr_accessor :name, :desc, :allowed_values, :default
  def initialize(name)
    @name = name
  end
  
  def desc(d = nil)
    d ? @desc = d : @desc
  end
  
  def values(vals = nil)
    vals ? @allowed_values = vals : @allowed_values
  end

  def default(val = nil)
    val ? @default = val : @default
  end
end

def api(name, &block)
  @api = Api.new(name)
  @api.instance_eval(&block)
  haml_path = File.join(File.dirname(__FILE__), "api.haml")
  haml = open(haml_path).read
  engine = Haml::Engine.new(haml)
  puts engine.render @api
end

LICENSE_PARAMS = ActiveSupport::OrderedHash.new
LICENSE_PARAMS[:none]          = "No license specified, observer witholds all rights to distribution."
LICENSE_PARAMS[:any]           = "Observation licensed, see response for license specified."
LICENSE_PARAMS["CC-BY"]        = "Creative Commons Attribution License"
LICENSE_PARAMS["CC-BY-NC"]     = "Creative Commons Attribution-NonCommercial License"
LICENSE_PARAMS["CC-BY-SA"]     = "Creative Commons Attribution-ShareAlike License"
LICENSE_PARAMS["CC-BY-ND"]     = "Creative Commons Attribution-NoDerivs License"
LICENSE_PARAMS["CC-BY-NC-SA"]  = "Creative Commons Attribution-NonCommercial-ShareAlike License"
LICENSE_PARAMS["CC-BY-NC-ND"]  = "Creative Commons Attribution-NonCommercial-NoDerivs License"

api "iNaturalist API" do
  desc <<-EOT
The iNat API is a set of REST endpoints that can be used to read data from
iNat and write data back on the behalf of users. Data can be retrieved in
different formats by appending
<code>.[format]</code> to the endpoint, e.g. <code>/observations.json</code>
to retrieve observations as JSON. Read-only endpoints generally do not require
authentication, but if you want to access data like unobscured coordinates on
behalf of users or write data to iNat, you will need to make authenticated
requests (see below).
EOT
  post "/comments", :auth_required => true do
    desc "Create comments. Comments are automatically associated with the signed in user."
    formats %w(json)
    param "comment[parent_type]" do
      desc "Type of parent record to which this comment is being added."
      values %w(AssessmentSection ListedTaxon Observation ObservationField Post TaxonChange)
    end

    param "comment[parent_id]" do
      desc "Parent record ID"
      values "Valid iNat record ID"
    end

    param "comment[body]" do
      desc "Comment body."
    end
  end

  put "/comments/:id", :auth_required => true do
    desc "Update a comment. Params are the same as POST /comments."
    formats %w(json)
  end

  delete "/comments/:id", :auth_required => true do
    desc "Delete a comment."
    formats %w(json)
  end

  post "/identifications", :auth_required => true do
    desc "Create identifications. Identifications are automatically associated with the signed in user."
    formats %w(json)
    
    param "identification[observation_id]" do
      desc "ID of the associated observation"
      values "Valid iNat observation ID"
    end

    param "identification[taxon_id]" do
      desc "ID of the associated taxon"
      values "Valid iNat taxon ID"
    end

    param "identification[body]" do
      desc "Optional user remarks on the identification."
    end
  end

  put "/identifications/:id", :auth_required => true do
    desc "Update a identification. Params are the same as POST /identifications."
    formats %w(json)
  end

  delete "/identifications/:id", :auth_required => true do
    desc "Delete a identification."
    formats %w(json)
  end
  
  get "/observations" do
    desc <<-EOT
Primary endpoint for retrieving observations. If you're looking for
pagination info, check the X headers in the response. You should see 
<code>X-Total-Entries</code>, <code>X-Page</code>, and 
<code>X-Per-Page</code>. JSON
and ATOM responses are what you'd expect, but DwC is 
<a href='http://rs.tdwg.org/dwc/terms/simple/index.htm'>Simple Darin Core</a>, an
XML schema for biodiversity data. iNat uses JSON responses internally quite a
bit, so it will probably always be the most information-rich. The widget
response is a JS snippet that inserts HTML.  It should be used
with a script tag, e.g. <pre>&lt;script
src="http://www.inaturalist.org/observations.widget"&gt;&lt;/script&gt;</pre>.
Note that while this endpoint doesn't require authentication under normal
circumstances, it WILL require it when you request pages higher than 100. If
you're going to scrape us, we want to know who you are.
EOT
    formats %w(atom csv dwc json kml widget)
    example do
      request "/observations.json"
      response <<-EOT
[{
    "user_login": "greatjon",
    "place_guess": "San Francisco, San Francisco",
    "location_is_exact": false,
    "quality_grade": "casual",
    "latitude": 37.713539,
    "created_at": "2012-04-10T21:48:25-07:00",
    "timeframe": null,
    "species_guess": "gray wolf",
    "observed_on": "2012-04-10",
    "num_identification_disagreements": 0,
    "delta": true,
    "updated_at": "2012-04-10T21:49:50-07:00",
    "num_identification_agreements": 0,
    "license": null,
    "geoprivacy": null,
    "positional_accuracy": 354,
    "coordinates_obscured": false,
    "taxon_id": 42048,
    "id_please": false,
    "id": 2281,
    "iconic_taxon": {
        "name": "Mammalia",
        "ancestry": "48460/1/2",
        "rank": "class",
        "id": 40151,
        "rank_level": 50,
        "iconic_taxon_name": "Mammalia"
    },
    "time_observed_at_utc": "2012-04-11T04:47:55Z",
    "user_id": 53,
    "time_observed_at": "2012-04-10T21:47:55-07:00",
    "observed_on_string": "Tue Apr 10 2012 21:47:55 GMT-0700 (PDT)",
    "short_description": "",
    "time_zone": "Pacific Time (US & Canada)",
    "out_of_range": null,
    "longitude": -122.340054,
    "description": "",
    "user": {
        "login": "greatjon"
    },
    "positioning_method": null,
    "map_scale": null,
    "photos": [],
    "iconic_taxon_name": "Mammalia",
    "positioning_device": null,
    "iconic_taxon_id": 40151
}]
      EOT
    end
    param "q" do
      desc <<-TXT
        Search query. Note that this is largely intended to be used on its own
        and may yield unexpected or limited results when used with other
        filters. If you're trying to retrieve observations of a particular
        taxon, taxon_id and taxon_name are better options.
      TXT
      values "any string"
    end
    
    param "page" do
      values "any integer"
    end
    
    param "per_page" do
      values 1..200
    end
    
    param "order_by" do
      desc "Field to sort by"
      values :observed_on => "date observed", :date_added => "date added to iNat"
    end
    
    param "order" do
      desc "Sort order"
      values %w(asc desc)
    end
    
    param "license" do
      desc "Specify the license users have applied to their observations."
      values LICENSE_PARAMS
    end
    
    param "photo_license" do
      desc "Filter by the license of the associated photos."
      values "Same as license param"
    end

    param "taxon_id" do
      desc "Filter by iNat taxon ID. Note that this will also select observations of descendant taxa."
      values "valid iNat taxon ID"
    end
    
    param "taxon_name" do
      desc "Filter by iNat taxon name. Note that this will also select observations of descendant taxa. Note that names are not unique, so if the name matches multiple taxa, no observations may be returned."
      values "Name string"
    end
    
    param "iconic_taxa[]" do
      desc "Filter by iconic taxa.  Can be used multiple times, e.g. iconic_taxa[]=Fungi&iconic_taxa[]=Mammalia"
      values ["Plantae", "Animalia", "Mollusca", "Reptilia", "Aves", "Amphibia", "Actinopterygii", "Mammalia", "Insecta", "Arachnida", "Fungi", "Protozoa", "Chromista", "unknown"]
    end
    
    param "has[]" do
      desc "Catch-all for some boolean selectors. This can be used multiple times, e.g. has[]=photos&has[]=geo"
      vals = ActiveSupport::OrderedHash.new
      vals[:photos] = "only show observations with photos"
      vals[:geo] = "only show georeferenced observations"
      vals[:id_please] = "only show observations in need of ID help"
      values vals
    end
    
    param "quality_grade" do
      desc "Filter by quality grade"
      values %w(casual research)
    end
    
    param "out_of_range" do
      desc "Filter by whether or not iNat considers the observation out of range for the associated taxon.  This is based on iNat's range data."
      values "true"
    end
    
    param "on" do
      desc "Filter by date string"
      values "Date strings in the form yyyy-mm-dd, e.g. 2001-05-02. You can also omit day and/or month, e.g. 2001-05 and 2001"
    end
    
    param "year" do
      desc "Filter by year"
      values "any integer"
    end
    
    param "month" do
      desc "Filter by month"
      values 1..12
    end
    
    param "day" do
      desc "Filter by day of the month"
      values 1..31
    end

    param "d1" do
      desc "First date of a date range"
      values "Date strings in the form yyyy-mm-dd, e.g. 2001-05-02."
    end

    param "d2" do
      desc "Last date of a date range"
      values "Date strings in the form yyyy-mm-dd, e.g. 2001-05-02."
    end

    param "m1" do
      desc "First month of a month range"
      values 1..12
    end

    param "m2" do
      desc "Last month of a month range"
      values 1..12
    end

    param "h1" do
      desc "First hour of a hour range"
      values 0..23
    end

    param "h2" do
      desc "Last hour of a hour range"
      values 0..23
    end
    
    param "swlat" do
      desc "Southwest latitude of a bounding box query."
      values -90..90
    end
    
    param "swlng" do
      desc "Southwest longitude of a bounding box query."
      values -180..180
    end
    
    param "nelat" do
      desc "Northeast latitude of a bounding box query."
      values -90..90
    end
    
    param "nelng" do
      desc "Northeast longitude of a bounding box query."
      values -180..180
    end

    param "list_id" do
      desc "Restrict results to observations of taxa on the specifified list. Limited to lists with 2000 taxa or less."
      values "iNat list ID"
    end

    param "updated_since" do
      desc <<-EOT
        Filter by observations that have been updated since a timestamp.
      EOT
      values "ISO 8601 datetime, e.g. 2013-10-09T13:40:13-07:00"
    end

    param "extra" do
      desc <<-EOT
        Retrieve additional information. 'projects' returns info about the
        projects the observations have been added to, 'fields' returns
        observation field values, 'observation_photos' returns information
        about the photos' relationship with the observation, like their order.
      EOT
      values %w(fields identifications projects)
    end
  end

  post "/observations", :auth_required => true do
    desc <<-EOT
      Primary endpoint for creating observations. POST params can be specified
      for a single observation (e.g. observation[species_guess]) or as
      multiple to add a multiple observations at a time (e.g.
      observations[0][species_guess]).
    EOT
    formats %w(html json)

    param "observation[species_guess]" do
      desc <<-EOT
        Equivalent of the "What did you see?" field on the observation form,
        this is the name of the organism observed. If the taxon ID is absent,
        iNat will try to choose a single taxon based on this string, but it
        may fail if there's some taxonomic amgiguity.
      EOT
    end

    param "observation[taxon_id]" do
      desc <<-EOT
        ID of the taxon to associate with this observation. An identification
        for this taxon will automatically be added for the user."
      EOT
      values "valid iNat taxon ID"
    end

    param "observation[id_please]" do
      desc "Whether or not the user needs ID help"
      values [0,1]
    end

    param "observation[observed_on_string]" do
      desc "Text representation of the date/time of the observation."
      values <<-EOT
        iNat is pretty flexible in the dates it can parse out of this value. Here are some examples
        <ul>
          <li>2 days ago</li>
          <li>January 21st, 2010</li>
          <li>2012-01-05</li>
          <li>October 30, 2008 10:31PM</li>
          <li>2011-12-23T11:52:06-0500</li>
          <li>July 9, 2012 7:52:39 AM ACST</li>
          <li>September 27, 2012 8:09:50 AM GMT+01:00</li>
        </ul>
        The only constraint is that dates may not be in the future. Time zone
        will default to the user's default time zone if not specified.
      EOT
    end

    param "observation[time_zone]" do
      desc "Time zone the observation was made in."
      values [
        "Abu Dhabi",
        "Adelaide",
        "Africa/Johannesburg",
        "Alaska",
        "Almaty",
        "American Samoa",
        "Amsterdam",
        "Arizona",
        "Asia/Magadan",
        "Astana",
        "Athens",
        "Atlantic Time (Canada)",
        "Atlantic/Cape_Verde",
        "Auckland",
        "Australia/Perth",
        "Azores",
        "Baghdad",
        "Baku",
        "Bangkok",
        "Beijing",
        "Belgrade",
        "Berlin",
        "Bern",
        "Bogota",
        "Brasilia",
        "Bratislava",
        "Brisbane",
        "Brussels",
        "Bucharest",
        "Budapest",
        "Buenos Aires",
        "Cairo",
        "Canberra",
        "Cape Verde Is.",
        "Caracas",
        "Casablanca",
        "Central America",
        "Central Time (US & Canada)",
        "Chennai",
        "Chihuahua",
        "Chongqing",
        "Copenhagen",
        "Darwin",
        "Dhaka",
        "Dublin",
        "Eastern Time (US & Canada)",
        "Edinburgh",
        "Ekaterinburg",
        "Europe/London",
        "Fiji",
        "Georgetown",
        "Greenland",
        "Guadalajara",
        "Guam",
        "Hanoi",
        "Harare",
        "Hawaii",
        "Helsinki",
        "Hobart",
        "Hong Kong",
        "Indiana (East)",
        "International Date Line West",
        "Irkutsk",
        "Islamabad",
        "Istanbul",
        "Jakarta",
        "Jerusalem",
        "Kabul",
        "Kamchatka",
        "Karachi",
        "Kathmandu",
        "Kolkata",
        "Krasnoyarsk",
        "Kuala Lumpur",
        "Kuwait",
        "Kyiv",
        "La Paz",
        "Lima",
        "Lisbon",
        "Ljubljana",
        "London",
        "Madrid",
        "Magadan",
        "Marshall Is.",
        "Mazatlan",
        "Melbourne",
        "Mexico City",
        "Mid-Atlantic",
        "Midway Island",
        "Minsk",
        "Monrovia",
        "Monterrey",
        "Moscow",
        "Mountain Time (US & Canada)",
        "Mumbai",
        "Muscat",
        "Nairobi",
        "New Caledonia",
        "New Delhi",
        "Newfoundland",
        "Novosibirsk",
        "Nuku'alofa",
        "Osaka",
        "Pacific Time (US & Canada)",
        "Pacific/Majuro",
        "Pacific/Port_Moresby",
        "Paris",
        "Perth",
        "Port Moresby",
        "Prague",
        "Pretoria",
        "Quito",
        "Rangoon",
        "Riga",
        "Riyadh",
        "Rome",
        "Samoa",
        "Santiago",
        "Sapporo",
        "Sarajevo",
        "Saskatchewan",
        "Seoul",
        "Singapore",
        "Skopje",
        "Sofia",
        "Solomon Is.",
        "Sri Jayawardenepura",
        "St. Petersburg",
        "Stockholm",
        "Sydney",
        "Taipei",
        "Tallinn",
        "Tashkent",
        "Tbilisi",
        "Tehran",
        "Tijuana",
        "Tokelau Is.",
        "Tokyo",
        "UTC",
        "Ulaan Bataar",
        "Urumqi",
        "Vienna",
        "Vilnius",
        "Vladivostok",
        "Volgograd",
        "Warsaw",
        "Wellington",
        "West Central Africa",
        "Yakutsk",
        "Yerevan",
        "Zagreb"
      ]
    end

    param "observation[description]" do
      desc "Observation description"
    end

    param "observation[tag_list]" do
      desc "Comma-separated list of tags"
      values "Comma-separated strings"
    end

    param "observation[place_guess]" do
      desc <<-EOT
        Name of the place where the observation was recorded. Not that iNat
        will *not* try to automatically look up coordinates based on this
        string. That task is uncertain enough that the UI should perform it so
        the user can confirm it."
      EOT
      values "Any string"
    end

    param "observation[latitude]" do
      desc "Latitude of the observation. Presumed datum is WGS84."
      values -90..90
    end

    param "observation[longitide]" do
      desc "Longitide of the observation. Presumed datum is WGS84."
      values -180..180
    end

    param "observation[map_scale]" do
      desc "Google Maps zoom level at which to show this observation's map marker."
      values 0..19
    end

    param "observation[positional_accuracy]" do
      desc "Postional accuracy of the observation coordinates in meters."
      values "Any positive integer"
    end

    param "observation[geoprivacy]" do
      desc "Geoprivacy for the observation"
      values ["open", "obscured", "private"]
    end

    param "observation[observation_field_values_attributes][order]" do
      desc <<-EOT
        Nested fields for observation field values are specified in the
        observation_field_values_attributes param. <code>order</code> is just
        an integer starting with zero specifying the order of entry.
      EOT
      values <<-EOT
        ObservationFieldValue attributes. So you
        might specify an entire observation field value for an observation field with an ID of 1 as 
        <code>observation[observation_field_values_attributes][0][observation_field_id]=1&observation[observation_field_values_attributes][0][value]=foo</code>.
      EOT
    end

    param "flickr_photos[]" do
      desc <<-EOT
        List of Flickr photo IDs to add as photos for this observation. User
        must have their Flickr and iNat accounts connected and the user must
        own the photo on Flickr.
      EOT
      values "Valid Flickr photo ID of a photo belonging to the user. Flickr photo IDs are integers."
    end

    param "picasa_photos[]" do
      desc <<-EOT
        List of Picasa photo IDs to add as photos for this observation. User
        must have their Picasa and iNat accounts connected and the user must
        own the photo on Picasa.
      EOT
      values "Valid Flickr photo ID of a photo belonging to the user."
    end

    param "facebook_photos[]" do
      desc <<-EOT
        List of Facebook photo IDs to add as photos for this observation. User
        must have their Facebook and iNat accounts connected and the user must
        own the photo on Facebook.
      EOT
      values "Valid Facebook photo ID of a photo belonging to the user."
    end

    param "local_photos[]" do
      desc <<-EOT
        List of fields containing uploaded photo data. Request must have a
        Content-Type of "multipart." We recommend that you use the POST
        /observation_photos endpoint instead.
      EOT
      values "Photo data"
    end

    example do
      request <<-EOT
        /observations.json?
          observation[species_guess]=Northern+Cardinal&
          observation[taxon_id]=9083&
          observation[id_please]=0&
          observation[observed_on_string]=2013-01-03&
          observation[time_zone]=Eastern+Time+(US+%26+Canada)&
          observation[description]=what+a+cardinal&
          observation[tag_list]=foo,bar&
          observation[place_guess]=clinton,+ct&
          observation[latitude]=41.27872259999999&
          observation[longitude]=-72.5276073&
          observation[map_scale]=11&
          observation[location_is_exact]=false&
          observation[positional_accuracy]=7798&
          observation[geoprivacy]=obscured&
          observation[observation_field_values_attributes][0][observation_field_id]=5&
          observation[observation_field_values_attributes][0][value]=male&
          flickr_photos[0]=8331632744
      EOT
      response <<-EOJS
        [
          {
            "created_at": "2013-01-15T15:04:57-05:00",
            "delta": true,
            "description": "what a cardinal",
            "geoprivacy": "obscured",
            "iconic_taxon_id": 3,
            "id": 3281,
            "id_please": false,
            "latitude": "41.2995543746",
            "license": "CC-BY",
            "location_is_exact": false,
            "longitude": "-72.5571845909",
            "map_scale": 11,
            "num_identification_agreements": 0,
            "num_identification_disagreements": 0,
            "observed_on": "2013-01-03",
            "observed_on_string": "2013-01-03",
            "out_of_range": null,
            "place_guess": "clinton, ct",
            "positional_accuracy": 7798,
            "positioning_device": null,
            "positioning_method": null,
            "quality_grade": "casual",
            "species_guess": "Northern Cardinal",
            "taxon_id": 9083,
            "time_observed_at": null,
            "time_zone": "Eastern Time (US & Canada)",
            "timeframe": null,
            "updated_at": "2013-01-15T17:10:02-05:00",
            "uri": "http://www.inaturalist.org/observations/3281",
            "user_id": 1,
            "user_login": "kueda",
            "iconic_taxon_name": "Aves",
            "created_at_utc": "2013-01-15T20:04:57Z",
            "updated_at_utc": "2013-01-15T22:10:02Z",
            "time_observed_at_utc": null,
            "coordinates_obscured": true,
            "observation_field_values": [{
              "created_at": "2013-01-15T15:05:00-05:00",
              "id": 403,
              "observation_field_id": 5,
              "observation_id": 3281,
              "updated_at": "2013-01-15T15:05:00-05:00",
              "value": "male"
            }],
            "project_observations": [],
            "observation_photos": [{
              "created_at": "2013-01-15T15:04:59-05:00",
              "id": 995,
              "observation_id": 3281,
              "photo_id": 1298,
              "position": null,
              "updated_at": "2013-01-15T15:04:59-05:00",
              "photo": {
                "created_at": "2013-01-15T15:04:59-05:00",
                "file_content_type": null,
                "file_file_name": null,
                "file_file_size": null,
                "file_processing": null,
                "file_updated_at": null,
                "id": 1298,
                "large_url": "http://farm9.staticflickr.com/8499/8331632744_8a0fc40fbb_b.jpg",
                "license": 2,
                "medium_url": "http://farm9.staticflickr.com/8499/8331632744_8a0fc40fbb.jpg",
                "metadata": null,
                "mobile": false,
                "native_page_url": "http://www.flickr.com/photos/ken-ichi/8331632744/",
                "native_photo_id": "8331632744",
                "native_realname": "Ken-ichi Ueda",
                "native_username": "Ken-ichi",
                "original_url": "http://farm9.staticflickr.com/8499/8331632744_f84c5a3f3c_o.jpg",
                "small_url": "http://farm9.staticflickr.com/8499/8331632744_8a0fc40fbb_m.jpg",
                "square_url": "http://farm9.staticflickr.com/8499/8331632744_8a0fc40fbb_s.jpg",
                "thumb_url": "http://farm9.staticflickr.com/8499/8331632744_8a0fc40fbb_t.jpg",
                "updated_at": "2013-01-15T17:10:01-05:00",
                "user_id": 1
              }
            }]
          }
        ]
      EOJS
    end
  end

  get "/observations/:id" do
    desc "Retrieve information about an observation"
    formats %w(json)
  end

  put "/observations/:id", :auth_required => true do
    desc <<-EOT
      Update a single observation. Not that since most HTTP clients do not
      support PUT requests, you can fake it be specifying a _method param.

      This basically takes all the same params as POST /observations using the
      observation[] params. Here we're documenting some additional params for
      updating.
    EOT

    param "_method" do
      desc "HTTP method to use if your client doesn't support PUT"
      values "put"
    end

    param "ignore_photos" do
      desc <<-EOT
        Ignore the absence of photo params. iNat assumes you are submitting
        data about existing photos with each request to update an observation,
        since that's how the HTML form works. If they're absent, iNat assumes
        the user wanted to remove those photos. Setting this param will
        override this behavior and leave any existing photos in place.
      EOT
      values [0,1]
    end

    param "observation[observation_field_values_attributes][order]" do
      desc <<-EOT
        Again, pretty much the same as POST /observations, but you can update
        existing ObservationFieldValues by including their IDs, and remove
        them using the <code>_delete</code> param.
      EOT
      values <<-EOT
        ObservationFieldValue attributes. You could update an
        ObservationFieldValue with an ID of 1 with
        <code>observation[observation_field_values_attributes][0][id]=1&observation[observation_field_values_attributes][0][value]=foo</code>. 
        You could delete the same with 
        <code>observation[observation_field_values_attributes][0][id]=1&observation[observation_field_values_attributes][0][_delete]=true</code>
      EOT
    end
  end

  delete "/observations/:id", :auth_required => true do
    desc "Delete an observation. Authenticated user must own the observation."
    formats %w(json)
    example do
      request <<-EOT
        /observations/297867.json
      EOT
      response <<-EOJS
{
  "comments_count": 1,
  "community_taxon_id": 71992,
  "created_at": "2013-06-17T15:46:47Z",
  "delta": false,
  "description": "",
  "geoprivacy": "private",
  "iconic_taxon_id": 47126,
  "id": 297867,
  "id_please": false,
  "latitude": null,
  "license": "CC-BY",
  "location_is_exact": false,
  "longitude": null,
  "map_scale": null,
  "num_identification_agreements": 0,
  "num_identification_disagreements": 1,
  "oauth_application_id": null,
  "observed_on": "2013-06-12",
  "observed_on_string": "2013-06-12 15:00:20",
  "out_of_range": null,
  "photos_count": 1,
  "place_guess": "New Haven, Connecticut, United States",
  "positional_accuracy": null,
  "positioning_device": null,
  "positioning_method": null,
  "quality_grade": "research",
  "sounds_count": 0,
  "species_guess": "Asplenium trichomanes",
  "taxon_id": 75609,
  "time_observed_at": "2013-06-12T19:00:20Z",
  "time_zone": "Eastern Time (US & Canada)",
  "timeframe": null,
  "updated_at": "2013-07-08T19:08:27Z",
  "uri": "http://www.inaturalist.org/observations/297867",
  "user_id": 1,
  "zic_time_zone": "America/New_York",
  "user_login": "kueda",
  "iconic_taxon_name": "Plantae",
  "created_at_utc": "2013-06-17T15:46:47Z",
  "updated_at_utc": "2013-07-08T19:08:27Z",
  "time_observed_at_utc": "2013-06-12T19:00:20Z",
  "coordinates_obscured": true,
  "observation_field_values": [],
  "project_observations": [{
    "created_at": "2013-06-17T16:22:04Z",
    "curator_identification_id": null,
    "id": 399,
    "observation_id": 297867,
    "project_id": 243,
    "tracking_code": null,
    "updated_at": "2013-06-17T16:22:04Z",
    "project": {
      "id": 243,
      "title": "McLaren Park Bioblitz",
      "icon_url": null
    }
  }],
  "observation_photos": [{
    "created_at": "2013-06-17T15:46:51Z",
    "id": 1221,
    "observation_id": 297867,
    "photo_id": 1582,
    "position": null,
    "updated_at": "2013-06-17T15:46:51Z",
    "photo": {
      "created_at": "2013-06-17T15:46:47Z",
      "file_updated_at": "2013-06-17T17:25:36Z",
      "id": 1582,
      "large_url": "http://staticdev.inaturalist.org/photos/1582/large.jpg?1371489936",
      "license": 4,
      "medium_url": "http://staticdev.inaturalist.org/photos/1582/medium.jpg?1371489936",
      "native_page_url": "http://www.inaturalist.org/photos/1582",
      "native_username": "kueda",
      "small_url": "http://staticdev.inaturalist.org/photos/1582/small.jpg?1371489936",
      "square_url": "http://staticdev.inaturalist.org/photos/1582/square.jpg?1371489936",
      "thumb_url": "http://staticdev.inaturalist.org/photos/1582/thumb.jpg?1371489936",
      "updated_at": "2013-06-17T17:25:46Z",
      "license_code": "CC-BY",
      "attribution": "(c) kueda, some rights reserved (CC BY)"
    }
  }],
  "comments": [{
    "body": "Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.",
    "created_at": "2013-06-17T18:19:21Z",
    "id": 173,
    "parent_id": 297867,
    "parent_type": "Observation",
    "updated_at": "2013-06-17T18:19:21Z",
    "user_id": 168,
    "user": {
      "id": 168,
      "login": "munz",
      "name": null
    }
  }]
}
      EOJS
    end
  end
  
  get "/observations/:username" do
    desc "Mostly the same as /observations except filtered by a username."
    
    param "updated_since" do
      desc <<-EOT
        Behaves the same as it does with GET /observations, with the addition
        of an extra HTTP header in the response. Since this is mainly used for
        syncing with 3rd party services and devices, this will also include an
        HTTP header called X-Deleted-Observations that contains a comma-
        separated list of observation IDs that have been deleted.
      EOT
      values "ISO 8601 datetime, e.g. 2013-10-09T13:40:13-07:00"
    end
  end
  
  get "/observations/project/:id" do
    desc "Just like /observations except filtered by a project.  :id can be a project ID or slug. CSV response will return some extra project-specific daa."
    formats %w(atom csv json kml widget)
  end

  get "/observations/taxon_stats" do
    desc <<-EOT
      Retrieve some stats about taxa within a range of observations.
      <code>species_counts</code> are counts of observations identified to the
      species level or lower. <code>total</code> is the total number of taxa
      of all ranks. You must include the <code>on</code>, <code>d1/d2</code>,
      <code>place_id</code>, <code>user_id</code>, or <code>projects</code>
      params or this endpoint will just return blank results. This endpoint
      should accept all the params available for <code>/observations</code>.
    EOT
    formats %w(json)
    example do
      request "/observations/taxon_stats.json?on=2008-03-19"
      response <<-EOT
{
  total: 40,
  species_counts: [
    {
      count: "2",
      taxon: {
        id: 8649,
        name: "Calocitta formosa",
        rank: "species",
        rank_level: 10,
        default_name: {
          created_at: "2011-05-17T20:12:15-07:00",
          creator_id: null,
          id: 139851,
          is_valid: true,
          lexicon: "English",
          name: "White-throated Magpie-Jay",
          name_provider: null,
          source_id: null,
          source_identifier: null,
          source_url: null,
          taxon_id: 8649,
          updated_at: "2011-05-17T20:12:15-07:00",
          updater_id: null
        },
        image_url: "http://farm6.staticflickr.com/5179/5479426866_e0f6740520_s.jpg",
        iconic_taxon_name: "Aves",
        conservation_status_name: "least_concern"
      }
    }
  ],
  rank_counts: {
    superfamily: "1",
    genus: "1",
    species: "36",
    family: "2"
  }
}
      EOT
    end
  end

  get "/observations/user_stats" do
    desc <<-EOT
      Retrieve some stats about users within a range of observations.
      You must include the <code>on</code>, <code>d1/d2</code>,
      <code>place_id</code>, <code>user_id</code>, or <code>projects</code>
      params or this endpoint will just return blank results. This endpoint
      should accept all the params available for <code>/observations</code>.
    EOT
    formats %w(json)
    example do
      request "/observations/user_stats.json?on=2008-03-19"
      response <<-EOT
{
  "total": 20,
  "most_observations": [{
    "count": "9",
    "user": {
      id: "1",
      count: "2",
      user: {
        id: 1,
        login: "kueda",
        name: "Ken-ichi Ueda",
        user_icon_url: "http://www.inaturalist.org/attachments/users/icons/1-thumb.jpg"
      }
    }
  }, ...],
  "most_species": [{
    "count": "9",
    "user": {
      id: "1",
      count: "2",
      user: {
        id: 1,
        login: "kueda",
        name: "Ken-ichi Ueda",
        user_icon_url: "http://www.inaturalist.org/attachments/users/icons/1-thumb.jpg"
      }
    }
  }, ...]
}
      EOT
    end
  end

  put "/observations/:id/viewed_updates" do
    desc "Mark updates associated with this observation (e.g. new comment notifications) as viewed. Response should be NO CONTENT."
    formats %w(json)
  end

  get "/observation_fields" do
    desc <<-EOT
      List / search observation fields. ObservationFields are basically
      typed data fields that users can attach to observation.
    EOT
    formats %w(json)
    param "q" do
      desc "Search query"
      values "Any string"
    end
    param "page" do
      values "any integer"
    end
  end

  post "/observation_field_values", :auth_required => true do
    desc <<-EOT
      Create a new observation field value. ObservationFields are basically
      typed data fields that users can attach to observation.
      ObservationFieldValues are the instaces of those fields. Note that you
      can also create these with nested params in POST /observations.
    EOT
    formats %w(json)
    param "observation_field_value[observation_id]" do
      desc "ID of the observation receiving this observation field value."
      values "Valid iNat observation ID"
    end
    param "observation_field_value[observation_field_id]" do
      desc "ID of the observation field for this observation field value."
      values "Valid iNat observation field ID"
    end
    param "observation_field_value[value]" do
      desc "Value for the observation field value."
      values "Any string, but check the field's allowed values."
    end
  end

  put "/observation_field_values/:id", :auth_required => true do
    desc "Update an observation field value. Parans are the same as POST /observation_field_values"
    formats %w(json)
  end

  delete "/observation_field_values/:id", :auth_required => true do
    desc "Delete observation field value."
    formats %w(json)
  end

  post "/observation_photos", :auth_required => true do
    desc <<-EOT
      Add photos to observations. This is only for iNat-hosted photos. For
      adding photos hosted on other services, see POST /observations and PUT
      /observations/:id.
    EOT

    param "observation_photo[observation_id]" do
      desc "ID of the observation receiving this photo."
      values "Valid iNat observation ID"
    end
    param "file" do
      desc "The photo data."
      values "Multipart photo data"
    end
  end

  get "/places" do
    desc "Retrieve information about places."
    formats %w(json)

    param "page" do
      values "any integer"
      default 1
    end
    
    param "per_page" do
      values 1..200
      default 30
    end
    
    param "ancestor_id" do
      values "Place ID integer"
      desc "Filter places by an ancestor place based on place hierarchy. If you wanted to view all places that are a part of California, you would set ancestor_id=14."
    end

    param "place_type" do
      desc "Type of place to retrieve"
      values ["Undefined", "Street Segment", "Street", "Intersection", "Street", "Town", "State", "County", "Local Administrative Area", "Country", "Island", "Airport", "Drainage", "Land Feature", "Miscellaneous", "Nationality", "Supername", "Point of Interest", "Region", "Colloquial", "Zone", "Historical State", "Historical County", "Continent", "Estate", "Historical Town", "Aggregate", "Open Space"].sort
    end
    
    param "taxon" do
      desc <<-EOT
        Retrieve places with this taxon on their check lists. Can be specified as an ID or a name, though vernacular names may yield unpredictable results.
        Note that this gets a bit weird for continents, since they don't have check lists: continents will not be returned *unless* place_type=continent.
      EOT
      values "Taxon ID or name"      
    end

    param "establishment_means" do
      desc <<-EOT
        Filter taxon-specific place searches by how the taxon was established
        there, e.g. if it is native, introduced, invasive, etc. Note: searches
        for "native" will return places where the taxon is "native" or
        "endemic," and searches for "introduced" will return places where the
        taxon is "introduced," "naturalised," "invasive," or "managed."
      EOT
      values %w(native endemic introduced naturalised invasive managed)
    end

    param "latitude" do
      desc "Retrieve places that contain this lat/lon combination. This will only return places with boundaries defined."
      values "Decimal latitude, e.g. 12.345"
    end

    param "longitude" do
      desc "See latitude"
      values "Decimal longitude, e.g. 12.345"
    end

    example do
      request "/places.json?taxon=Calochortus+tiburonensis&place_type=open+space"
      response <<-EOJS
  [{
    "ancestry": "1/14/2319",
    "check_list_id": 6079,
    "code": null,
    "created_at": "2009-06-29T22:24:50-07:00",
    "display_name": "Ring Mountain Open Space Preserve, CA, US",
    "id": 3104,
    "latitude": "37.9130554199",
    "longitude": "-122.4938278198",
    "name": "Ring Mountain Open Space Preserve",
    "nelat": "37.92107",
    "nelng": "-122.48223",
    "parent_id": 2319,
    "place_type": 100,
    "source_identifier": "Ring Mountain Preserve",
    "source_name": "Ring Mountain Preserve",
    "swlat": "37.90504",
    "swlng": "-122.50542",
    "updated_at": "2012-09-26T03:14:01-07:00",
    "user_id": null,
    "woeid": null,
    "place_type_name": "Open Space"
  }]
        EOJS
      end
      
      example do
        request "/places.json?place_type=state&q=California"
        response <<-EOJS
  [{
    "ancestry": "1",
    "check_list_id": 312,
    "code": "US-CA",
    "created_at": "2009-06-29T21:46:28-07:00",
    "display_name": "California, US",
    "id": 14,
    "latitude": "37.2691993713",
    "longitude": "-119.3069992065",
    "name": "California",
    "nelat": "42.008804",
    "nelng": "-114.131211",
    "parent_id": 1,
    "place_type": 8,
    "source_identifier": "3195",
    "source_name": "3195",
    "swlat": "32.528832",
    "swlng": "-124.480543",
    "updated_at": "2012-09-26T03:13:52-07:00",
    "user_id": null,
    "woeid": 2347563,
    "place_type_name": "State"
  }, {
    "ancestry": "6793",
    "check_list_id": 7754,
    "code": "MX-BCN",
    "created_at": "2009-10-24T18:01:56-07:00",
    "display_name": "Baja California, MX",
    "id": 7403,
    "latitude": "30.3589992523",
    "longitude": "-114.9445877075",
    "name": "Baja California",
    "nelat": "32.71804",
    "nelng": "-112.4939948948",
    "parent_id": 6793,
    "place_type": 8,
    "source_identifier": "1805",
    "source_name": "1805",
    "swlat": "27.835026736",
    "swlng": "-118.4187830224",
    "updated_at": "2012-09-26T03:14:35-07:00",
    "user_id": null,
    "woeid": 2346265,
    "place_type_name": "State"
  }, {
    "ancestry": "6793",
    "check_list_id": 9190,
    "code": "MX-BCS",
    "created_at": "2010-06-28T12:49:24-07:00",
    "display_name": "Baja California Sur, MX",
    "id": 8501,
    "latitude": "25.4334506989",
    "longitude": "-111.53881073",
    "name": "Baja California Sur",
    "nelat": "28.0027035634",
    "nelng": "-109.362976567",
    "parent_id": 6793,
    "place_type": 8,
    "source_identifier": "1806",
    "source_name": "1806",
    "swlat": "18.2910523956",
    "swlng": "-115.8180955045",
    "updated_at": "2012-09-26T03:14:37-07:00",
    "user_id": null,
    "woeid": 2346266,
    "place_type_name": "State"
  }]
  EOJS
    end
  end
  
  get "/projects" do
    desc "Retrieve information about projects on iNaturalist."
    formats %w(json)
    
    param "page" do
      desc "Results are returned in pages of 100 projects."
      values "any integer"
    end
    
    param "featured" do
      desc "Select only featured projects.  Featured projects are chosen by site admins."
      values "true"
    end
    
    param "latitude" do
      desc <<-EOT
        Search for observations within 5 degrees of a given point. Results are
        ordered by distance from that point. Geographic queries will only
        return projects that have an observation rule tied to a given place.
      EOT
      values -90..90
    end
    
    param "longitude" do
      desc "See latitude."
      values -180..180
    end
    
    param "source" do
      desc "Find projects by source, usually a URI identifying an external resource from which the project was derived."
    end
    
    example do
      request "/projects.json?featured=true"
      response <<-EOJS
[{
    "created_at": "2011-08-12T10:21:28-07:00",
    "created_at_utc": "2011-08-12T17:21:28Z",
    "title": "ASC Pika Project",
    "project_type": "contest",
    "project_observation_rule_terms": "must be on list",
    "updated_at": "2012-04-26T19:38:51-07:00",
    "updated_at_utc": "2012-04-27T02:38:51Z",
    "source_url": "",
    "id": 44,
    "user_id": 477,
    "featured_at": "2012-04-26T19:38:51-07:00",
    "featured_at_utc": "2012-04-27T02:38:51Z",
    "icon_url": "http://www.inaturalist.org/attachments/projects/icons/44/span2/APAlogo.png?1315005828",
    "icon_file_size": 9454,
    "icon_file_name": "APAlogo.png",
    "icon_content_type": "image/png",
    "description": "The goal of this project is to document the persistence or extirpation of American Pika throughout their range for science and conservation. <a href=\"/attachments/project_assets/95-flyer.html?1320257073\">Read our flyer</a> to find out more! According to the pika range map compiled by the <a href=\"http://www.iucnredlist.org/apps/redlist/details/41267/0\">IUCN</a>, American pika are thought to occur in two occur in 2 Countries, 12 States (or Canadian Provinces) and 276 Counties (or Canadian Regional Districts). We seek to collect recent observations verifying Pika persistence in each of these places. This project is supported by the North American Pika Consortium, the California Department of Fish and Game, and the Front Range Pika Project.",
    "cached_slug": "asc-pika-project",
    "project_list": {
        "comprehensive": false,
        "place_id": null,
        "created_at": "2011-08-12T12:33:04-07:00",
        "created_at_utc": "2011-08-12T19:33:04Z",
        "title": "American Pika Atlas's Check List",
        "updated_at": "2011-08-12T12:33:04-07:00",
        "project_id": 44,
        "updated_at_utc": "2011-08-12T19:33:04Z",
        "taxon_id": null,
        "id": 52561,
        "user_id": null,
        "last_synced_at": null,
        "description": "Every species observed by members of American Pika Atlas",
        "source_id": null
    },
    "terms": "Please only upload observations if you agree to make them available non-commercial scientific analyses. We will attribute you as the photographer if your photos are used in any published scientific analyses. If possible please include locations, dates, and photos with your observations.",
    "observed_taxa_count": 2,
    "icon_updated_at": "2011-09-02T16:23:48-07:00",
    "rule_place": null,
    "project_observations_count": 12
}]
      EOJS
    end
  end

  get "/projects/:id" do
    desc "Retrieve information about a single project.  :id is the project ID or slug."
    formats %w(json)
  end
  
  get "/projects/:id?iframe=true" do
    desc "This returns a complete web page without header or footer suitable for use in an IFRAME."
  end
  
  get "/projects/:id/contributors.widget" do
    desc "JS widget snippet of the top contributors to a project."
  end

  get "/projects/user/:login", :auth_required => true do
    desc <<-EOT
Lists projects the user specified by <code>:login</code> has joined. Actually it lists our
ProjectUser records, which represent membership in a project.
EOT
    formats %w(json)
    example do
      request "http://www.inaturalist.org/projects/user/kueda.json"
      response <<-EOT
[{
  "created_at": "2012-05-02T15:27:13-04:00",
  "id": 63,
  "observations_count": 0,
  "project_id": 1,
  "role": "curator",
  "taxa_count": 0,
  "updated_at": "2012-05-02T15:35:22-04:00",
  "user_id": 23,
  "user": {
    "login": "kueda"
  },
  "project": {
    "created_at": "2011-09-18T17:10:07-04:00",
    "delta": false,
    "description": "In which we <a href=\"http://www.inaturalist.org\">observe</a> things that may or may not be like white whales.",
    "featured_at": null,
    "icon_content_type": "image/jpeg",
    "icon_file_name": "spilosoma.jpg",
    "icon_file_size": 119605,
    "icon_updated_at": "2011-09-18T17:10:05-04:00",
    "id": 1,
    "latitude": null,
    "longitude": null,
    "map_type": "terrain",
    "observed_taxa_count": 8,
    "place_id": null,
    "project_type": "contest",
    "slug": "white-whales-et-al",
    "source_url": "",
    "terms": "You must be awesome.  The thing you've observed must be like unto a white whale.",
    "title": "White Whales et al.",
    "updated_at": "2012-05-07T21:31:15-04:00",
    "user_id": 1,
    "zoom_level": null,
    "icon_url": "http://www.inaturalist.org/attachments/projects/icons/1/span2/spilosoma.jpg?1316380205",
    "project_observation_rule_terms": "",
    "featured_at_utc": null,
    "rule_place": null,
    "cached_slug": "white-whales-et-al",
    "project_list": {
      "comprehensive": false,
      "created_at": "2011-09-18T17:10:07-04:00",
      "description": "Every species observed by members of White Whales et al.",
      "id": 99143,
      "last_synced_at": null,
      "place_id": null,
      "project_id": 1,
      "show_obs_photos": true,
      "source_id": null,
      "taxon_id": null,
      "title": "White Whales et al.'s Check List",
      "updated_at": "2011-09-18T17:10:07-04:00",
      "user_id": null
    },
    "project_observation_fields": []
  }
}]
EOT
    end
  end

  get "/projects/:id/members", auth_required: true do
    desc "Get the users who have joined this project."
    param "page" do
      values "any integer"
    end
    param "per_page" do
      values 1..200
    end
  end

  post "/projects/:id/join", :auth_required => true do
    desc "Adds the authenticated user as a member of the project"
    formats %w(json)
  end

  delete "/projects/:id/leave", :auth_required => true do
    desc "Removes the authenticated user as a member of the project"
    formats %w(json)
  end

  post "/project_observations", :auth_required => true do
    desc "Add observations to projects"
    formats %w(json)
    param "project_observation[observation_id]" do
      desc "ID of the observation."
      values "Valid iNat observation ID"
    end
    param "project_observation[project_id]" do
      desc "ID of the project that will be receiving this contribution."
      values "Valid iNat project ID"
    end
  end

  post "/users" do
    desc "Create a new iNaturalist user"
    formats %w(json)
    param "user[email]" do
      desc "Email address of the user."
      values "Any valid email address."
    end
    param "user[login]" do
      desc "Username for this user."
      values "Must be within 3 and 40 characters and must not begin with a number."
    end
    param "user[password]" do
      desc "User password"
    end
    param "user[password_confirmation]" do
      desc "User password confirmation"
    end
    param "user[description]" do
      desc "User description, just a brief blurb in which they describe themselves."
    end
    param "user[time_zone]" do
      desc "User time zone, will be used as the default time zone for observations that don't specify a time zone."
      values "See <code>POST /observations</code> above for valid time zone values,"
    end

    example do
      request <<-EOT
POST /users.json?user[login]=karina&user[email]=foo@bar.net&
  user[password]=******&user[password_confirmation]=******
EOT
      response <<-EOT
{
  "created_at": "2013-03-19T04:17:42Z",
  "description": null,
  "email": "foo@bar.net",
  "icon_content_type": null,
  "icon_file_name": null,
  "icon_file_size": null,
  "icon_updated_at": null,
  "icon_url": null,
  "id": 2,
  "identifications_count": 0,
  "journal_posts_count": 0,
  "life_list_id": 3,
  "life_list_taxa_count": 0,
  "login": "karina",
  "name": null,
  "observations_count": 0,
  "time_zone": null,
  "updated_at": "2013-03-19T04:17:42Z",
  "uri": "http://www.inaturalist.org/users/2"
}
      EOT
    end
  end

  put "/users/:id", auth_required: true do
    desc "Update a user. Takes the same parameters as <code>POST /users</code> and response should be the same. :id is the user ID."
    formats %w(json)
  end

  get "/users/edit", :auth_required => true do
    desc "Retrieve user profile info. Response should be like <code>POST /users</code> above."
    formats %w(json)
  end

  get "/users/new_updates", :auth_required => true do
    desc "Get info about new updates for the authenticated user, e.g. comments and identifications on their content."
    formats %w(json)
    param "resource_type" do
      desc "Fitler by the type of resource that received the update, e.g. only show updates on your observations."
      values %w(ListedTaxon Observation Post)
    end
    param "notifier_type" do
      desc "Fitler by the type of resource that created the update, e.g. only show comments."
      values %w(Comment Identification)
    end
    param "notifier_types[]" do
      desc "Fitler by multiple notifier types."
      values %w(Comment Identification)
    end
    param "skip_view" do
      desc <<-EOT
        Skip marking updates as viewed when retrieving them. The
        default behavior is to assume that if you're hitting this endpoint on
        behalf of the user, they will have viewed the updates returned.
      EOT
      values [true, false]
    end
    example do
      request "GET /users/new_updates.json"
      response <<-EOT
[
  {
    created_at: "2013-10-07T16:22:43-07:00",
    id: 954,
    notification: "activity",
    notifier_id: 610,
    notifier_type: "Comment",
    resource_id: 1,
    resource_owner_id: 1,
    resource_type: "Post",
    subscriber_id: 1,
    updated_at: "2013-10-07T16:22:43-07:00",
    viewed_at: "2013-10-07T16:22:49-07:00"
  },
  {
    created_at: "2013-09-12T13:39:21-07:00",
    id: 945,
    notification: "activity",
    notifier_id: 607,
    notifier_type: "Comment",
    resource_id: 199,
    resource_owner_id: 1,
    resource_type: "Observation",
    subscriber_id: 1,
    updated_at: "2013-09-12T13:39:21-07:00",
    viewed_at: "2013-10-07T16:21:09-07:00"
  }
]
      EOT
    end
  end

end
