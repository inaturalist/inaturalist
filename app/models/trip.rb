class Trip < Post
  has_many :trip_taxa, :dependent => :destroy, :inverse_of => :trip
  has_many :trip_purposes, :dependent => :destroy
  has_many :taxa, :through => :trip_taxa
  belongs_to :place, :inverse_of => :trips
  accepts_nested_attributes_for :trip_purposes, :allow_destroy => true
  accepts_nested_attributes_for :trip_taxa, :allow_destroy => true

  before_validation :set_parent
  
  TRIP_PURPOSE_JOINS = [
    "JOIN trip_purposes tp ON tp.trip_id = posts.id"
  ]
  
  scope :year, lambda { |year| where( "EXTRACT(YEAR FROM start_time) = ?", year ) }
  scope :month, lambda { |month| where( "EXTRACT(MONTH FROM start_time) = ?", month ) }  
  scope :in_place, lambda { |place_id|
      joins("JOIN place_geometries ON place_geometries.place_id = #{place_id}").
      where("ST_Intersects(place_geometries.geom, ST_MakePoint(posts.longitude, posts.latitude))")
    }
  scope :taxon, lambda{ |taxon|
    joins( TRIP_PURPOSE_JOINS ).
    where( "tp.complete = true AND tp.resource_id IN (?)", [taxon.ancestor_ids, taxon.id].flatten )
  }  
  scope :user, lambda{ |user_id| where( "user_id = ?", user_id ) }
  
  def set_parent
    self.parent ||= self.user
  end

  def observations
    return Observation.where("1 = 2") if start_time.blank? || stop_time.blank?
    scope = Observation.by(user).between_dates(start_time, stop_time)
    scope = scope.in_place(place_id) unless place_id.blank?
    scope
  end

  def add_taxa_from_observations
    candidates = []
    observations.select("DISTINCT ON (observations.taxon_id) observations.*").
        includes(:taxon).where("observations.taxon_id IS NOT NULL").each do |o|
      next if self.trip_taxa.where(:taxon_id => o.taxon_id).exists?
      tt = TripTaxon.new(:trip => self, :taxon => o.taxon, :observed => true)
      tt.save
      candidates << tt
    end
    candidates
  end
  
  def obs_search_elastic_params
    return if start_time.blank? || stop_time.blank? || latitude.blank? ||
      longitude.blank? || radius.blank? || radius <= 0 || trip_purposes.empty?
    [
      {
        geo_distance: {
          distance: radius, # meters
          location: {
            lat: latitude.to_f,
            lon: longitude.to_f
          }
        }
      },
      { term: { "user.id": user_id } },
      { terms: { "taxon.ancestor_ids": trip_purposes.map( &:resource_id ) } },
      { range: { "time_observed_at": {
        gte: start_time.strftime("%FT%T%:z"),
        lte: stop_time.strftime("%FT%T%:z")
      } } }
    ]
  end
  
  def self.presence_absence( trips, taxon_id, place_id, year, month )
    return if taxon_id.blank? || trips.blank? || trips.empty?
    potential_trips = trips.select{ |t| t.obs_search_elastic_params }
    return if potential_trips.empty?
    query = {
      filters: [
        { term: { "taxon.ancestor_ids.keyword": taxon_id } },
      ],
      size: 0,
      aggregate: {
        trips: {
          filters: {
            filters: Hash[ potential_trips.map{ |trip|
              [ "trip_#{trip.id}", { bool: { must: trip.obs_search_elastic_params } } ]
            } ]
          }
        }
      }
    }
    query[:filters] << { term: { "place_ids.keyword": place_id } } unless place_id.blank?
    query[:filters] << { term: { "observed_on_details.year": year } } unless year.blank?
    query[:filters] << { term: { "observed_on_details.month": month } } unless month.blank?

    results = Observation.elastic_search( query )
    return Hash[results.response.aggregations.trips.buckets.map{ |k,v|
      [k.sub( "trip_", "" ).to_i, v.doc_count]
    }]
  end
end
