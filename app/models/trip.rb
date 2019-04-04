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
  scope :place, lambda{ |place| where("latitude > ? AND latitude <= ? AND longitude > ? AND longitude <= ?", place.swlat, place.nelat, place.swlng, place.nelng) }
  scope :taxon, lambda{ |taxon|
    joins( TRIP_PURPOSE_JOINS ).
    where( "tp.complete = true AND tp.resource_id IN (?)", [taxon.ancestor_ids, taxon.id].flatten )
  }  
  
  def set_parent
    self.parent ||= self.user
  end

  def observations
    return Observation.where("1 = 2") if start_time.blank? || stop_time.blank?
    scope = Observation.by(user).between_dates(start_time, stop_time)
    scope = scope.in_place(place_id) unless place_id.blank?
    scope
  end

  def editable_by?(u)
    return false unless u
    user_id == u.id
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
end
