#encoding: utf-8
class Observation < ActiveRecord::Base
  has_subscribers :to => {
    :comments => {:notification => "activity", :include_owner => true},
    :identifications => {:notification => "activity", :include_owner => true}
  }
  notifies_subscribers_of :user, :notification => "created_observations"
  notifies_subscribers_of :public_places, :notification => "new_observations", 
    :queue_if => lambda {|observation|
      observation.georeferenced? && !observation.taxon_id.blank?
    },
    :if => lambda {|observation, place, subscription|
      return false unless observation.georeferenced?
      return true if subscription.taxon_id.blank?
      return false if observation.taxon.blank?
      observation.taxon.ancestor_ids.include?(subscription.taxon_id)
    }
  notifies_subscribers_of :taxon_and_ancestors, :notification => "new_observations", 
    :queue_if => lambda {|observation| !observation.taxon_id.blank? },
    :if => lambda {|observation, taxon, subscription|
      return true if observation.taxon_id == taxon.id
      return false if observation.taxon.blank?
      observation.taxon.ancestor_ids.include?(subscription.resource_id)
    }
  acts_as_taggable
  acts_as_flaggable
  
  include Ambidextrous
  
  # Set to true if you want to skip the expensive updating of all the user's
  # lists after saving.  Useful if you're saving many observations at once and
  # you want to update lists in a batch
  attr_accessor :skip_refresh_lists, :skip_identifications
  
  # Set if you need to set the taxon from a name separate from the species 
  # guess
  attr_accessor :taxon_name
  
  # licensing extras
  attr_accessor :make_license_default
  attr_accessor :make_licenses_same
  
  MASS_ASSIGNABLE_ATTRIBUTES = [:make_license_default, :make_licenses_same]
  
  M_TO_OBSCURE_THREATENED_TAXA = 10000
  OUT_OF_RANGE_BUFFER = 5000 # meters
  PLANETARY_RADIUS = 6370997.0
  DEGREES_PER_RADIAN = 57.2958
  FLOAT_REGEX = /[-+]?[0-9]*\.?[0-9]+/
  COORDINATE_REGEX = /[^\d\,]*?(#{FLOAT_REGEX})[^\d\,]*?/
  LAT_LON_SEPARATOR_REGEX = /[\,\s]\s*/
  LAT_LON_REGEX = /#{COORDINATE_REGEX}#{LAT_LON_SEPARATOR_REGEX}#{COORDINATE_REGEX}/
  
  PRIVATE = "private"
  OBSCURED = "obscured"
  GEOPRIVACIES = [OBSCURED, PRIVATE]
  GEOPRIVACY_DESCRIPTIONS = {
    nil => "Everyone can see the coordinates unless the taxon is threatened.",
    OBSCURED => "Public coordinates shown as a random point within " + 
      "#{M_TO_OBSCURE_THREATENED_TAXA / 1000}KM of the true coordinates. " +
      "True coordinates are only visible to you and the curators of projects " + 
      "to which you add the observation.",
    PRIVATE => "Coordinates completely hidden from public maps, true " + 
      "coordinates only visible to you and the curators of projects to " + 
      "which you add the observation. Observations with private " + 
      "coordinates will still be used to verify place check lists.",
  }
  CASUAL_GRADE = "casual"
  RESEARCH_GRADE = "research"
  QUALITY_GRADES = [CASUAL_GRADE, RESEARCH_GRADE]
  
  LICENSES = [
    ["CC-BY", "Attribution", "This license lets others distribute, remix, tweak, and build upon your work, even commercially, as long as they credit you for the original creation. This is the most accommodating of licenses offered. Recommended for maximum dissemination and use of licensed materials."],
    ["CC-BY-NC", "Attribution-NonCommercial", "This license lets others remix, tweak, and build upon your work non-commercially, and although their new works must also acknowledge you and be non-commercial, they don't have to license their derivative works on the same terms."],
    ["CC-BY-SA", "Attribution-ShareAlike", "This license lets others remix, tweak, and build upon your work even for commercial purposes, as long as they credit you and license their new creations under the identical terms. All new works based on yours will carry the same license, so any derivatives will also allow commercial use."],
    ["CC-BY-ND", "Attribution-NoDerivs", "This license allows for redistribution, commercial and non-commercial, as long as it is passed along unchanged and in whole, with credit to you."],
    ["CC-BY-NC-SA", "Attribution-NonCommercial-ShareAlike", "This license lets others remix, tweak, and build upon your work non-commercially, as long as they credit you and license their new creations under the identical terms."],
    ["CC-BY-NC-ND", "Attribution-NonCommercial-NoDerivs", "This license is the most restrictive of the six main licenses, only allowing others to download your works and share them with others as long as they credit you, but they can't change them in any way or use them commercially."]
  ]
  LICENSE_CODES = LICENSES.map{|row| row.first}
  LICENSES.each do |code, name, description|
    const_set code.gsub(/\-/, '_'), code
  end
  PREFERRED_LICENSES = [CC_BY, CC_BY_NC]
  CSV_COLUMNS = [
    "id", 
    "species_guess",
    "scientific_name", 
    "common_name", 
    "iconic_taxon_name",
    "taxon_id",
    "id_please",
    "num_identification_agreements",
    "num_identification_disagreements",
    "observed_on_string",
    "observed_on", 
    "time_observed_at",
    "time_zone",
    "place_guess",
    "latitude", 
    "longitude",
    "positional_accuracy",
    "private_latitude",
    "private_longitude",
    "private_positional_accuracy",
    "geoprivacy",
    "positioning_method",
    "positioning_device",
    "out_of_range",
    "user_id", 
    "user_login",
    "created_at",
    "updated_at",
    "quality_grade",
    "license",
    "url", 
    "image_url", 
    "tag_list",
    "description",
  ]
  
  belongs_to :user, :counter_cache => true
  belongs_to :taxon, :counter_cache => true
  belongs_to :iconic_taxon, :class_name => 'Taxon', 
                            :foreign_key => 'iconic_taxon_id'
  has_many :observation_photos, :dependent => :destroy, :order => "id asc"
  has_many :photos, :through => :observation_photos
  
  # note last_observation and first_observation on listed taxa will get reset 
  # by CheckList.refresh_with_observation
  has_many :listed_taxa, :foreign_key => 'last_observation_id'
  has_many :first_listed_taxa, :class_name => "ListedTaxon", :foreign_key => 'first_observation_id'
  has_many :first_check_listed_taxa, :class_name => "ListedTaxon", :foreign_key => 'first_observation_id', :conditions => "listed_taxa.place_id IS NOT NULL"
  
  has_many :goal_contributions,
           :as => :contribution,
           :dependent => :destroy
  has_many :comments, :as => :parent, :dependent => :destroy
  has_many :identifications, :dependent => :destroy
  has_many :project_observations, :dependent => :destroy
  has_many :project_invitations, :dependent => :destroy
  has_many :projects, :through => :project_observations
  has_many :quality_metrics, :dependent => :destroy
  has_many :observation_field_values, :dependent => :destroy, :order => "id asc"
  has_many :observation_fields, :through => :observation_field_values
  has_many :observation_links
  has_and_belongs_to_many :posts
  
  define_index do
    indexes taxon.taxon_names.name, :as => :names
    indexes tags.name, :as => :tags
    indexes :species_guess, :sortable => true, :as => :species_guess
    indexes :description, :as => :description
    indexes :place_guess, :as => :place, :sortable => true
    indexes user.login, :as => :user, :sortable => true
    indexes :observed_on_string, :as => :observed_on_string
    has :user_id
    has :taxon_id
    
    # Sadly, the following doesn't work, because self_and_ancestors is not an
    # association.  I'm not entirely sure if there's a way to work the ancestry
    # query in as col in a SQL query on observations.  If at some point we
    # need to have the ancestor ids in the Sphinx index, though, we can always
    # add a col to the taxa table holding the ancestor IDs.  Kind of a
    # redundant, and it would slow down moves, but it might be worth it for
    # the snappy searches. --KMU 2009-04-4
    # has taxon.self_and_ancestors(:id), :as => :taxon_self_and_ancestors_ids
    
    has photos(:id), :as => :has_photos #, :type => :boolean
    has :created_at, :sortable => true
    has :observed_on, :sortable => true
    has :iconic_taxon_id
    has :id_please, :as => :has_id_please
    has "latitude IS NOT NULL AND longitude IS NOT NULL", 
      :as => :has_geo, :type => :boolean
    has 'RADIANS(latitude)', :as => :latitude,  :type => :float
    has 'RADIANS(longitude)', :as => :longitude,  :type => :float
    
    # HACK: TS doesn't seem to include attributes in the GROUP BY correctly
    # for Postgres when using custom SQL attr definitions.  It may or may not 
    # be fixed in more up-to-date versions, but the issue has been raised: 
    # http://groups.google.com/group/thinking-sphinx/browse_thread/thread/e8397477b201d1e4
    has :latitude, :as => :fake_latitude
    has :longitude, :as => :fake_longitude
    has :num_identification_agreements
    has :num_identification_disagreements
    # END HACK
    
    has "num_identification_agreements > num_identification_disagreements",
      :as => :identifications_most_agree, :type => :boolean
    has "num_identification_agreements > 0", 
      :as => :identifications_some_agree, :type => :boolean
    has "num_identification_agreements < num_identification_disagreements",
      :as => :identifications_most_disagree, :type => :boolean
    has project_observations(:project_id), :as => :projects #, :type => :multi
    has observation_field_values(:observation_field_id), :as => :observation_fields
    set_property :delta => :delayed
  end
  
  SPHINX_FIELD_NAMES = %w(names tags species_guess description place user observed_on_string)
  SPHINX_ATTRIBUTE_NAMES = %w(user_id taxon_id has_photos created_at 
    observed_on iconic_taxon_id id_please has_geo latitude longitude 
    fake_latitude fake_longitude num_identification_agreements 
    num_identification_disagreements identifications_most_agree 
    identifications_some_agree identifications_most_disagree projects)
  
  accepts_nested_attributes_for :observation_field_values, 
    :allow_destroy => true, 
    :reject_if => lambda { |attrs| attrs[:value].blank? }
  
  ##
  # Validations
  #
  validates_presence_of :user_id
  
  validate :must_be_in_the_past,
           :must_not_be_a_range
  
  validates_numericality_of :latitude,
    :allow_blank => true, 
    :less_than_or_equal_to => 90, 
    :greater_than_or_equal_to => -90
  validates_numericality_of :longitude,
    :allow_blank => true, 
    :less_than_or_equal_to => 180, 
    :greater_than_or_equal_to => -180
  
  before_validation :munge_observed_on_with_chronic,
                    :set_time_zone,
                    :set_time_in_time_zone,
                    :cast_lat_lon
  
  before_save :strip_species_guess,
              :set_taxon_from_species_guess,
              :set_taxon_from_taxon_name,
              :set_iconic_taxon,
              :keep_old_taxon_id,
              :set_latlon_from_place_guess,
              :reset_private_coordinates_if_coordinates_changed,
              :obscure_coordinates_for_geoprivacy,
              :obscure_coordinates_for_threatened_taxa,
              :set_geom_from_latlon,
              :set_license,
              :trim_user_agent,
              :update_identifications
  
  before_update :set_quality_grade
                 
  after_save :refresh_lists,
             :refresh_check_lists,
             :update_out_of_range_later,
             :update_default_license,
             :update_all_licenses
  after_create :set_uri
  before_destroy :keep_old_taxon_id
  after_destroy :refresh_lists_after_destroy, :refresh_check_lists
  
  ##
  # Named scopes
  # 
  
  # Area scopes
  scope :in_bounding_box, lambda { |swlat, swlng, nelat, nelng|
    if swlng.to_f > 0 && nelng.to_f < 0
      where('latitude > ? AND latitude < ? AND (longitude > ? OR longitude < ?)', 
        swlat.to_f, nelat.to_f, swlng.to_f, nelng.to_f)
    else
      where('latitude > ? AND latitude < ? AND longitude > ? AND longitude < ?', 
        swlat.to_f, nelat.to_f, swlng.to_f, nelng.to_f)
    end
  } do
    def distinct_taxon
      group("taxon_id").where("taxon_id IS NOT NULL").includes(:taxon)
    end
  end
  
  scope :in_place, lambda {|place|
    place_id = place.is_a?(Place) ? place.id : place.to_i
    joins("JOIN place_geometries ON place_geometries.place_id = #{place_id}").
    where(
      "(observations.private_latitude IS NULL AND ST_Intersects(place_geometries.geom, observations.geom)) OR " +
      "(observations.private_latitude IS NOT NULL AND ST_Intersects(place_geometries.geom, ST_Point(observations.private_longitude, observations.private_latitude)))"
    )
  }
  
  scope :in_taxons_range, lambda {|taxon|
    taxon_id = taxon.is_a?(Taxon) ? taxon.id : taxon.to_i
    joins("JOIN taxon_ranges ON taxon_ranges.taxon_id = #{taxon_id}").
    where(
      "(observations.private_latitude IS NULL AND ST_Intersects(taxon_ranges.geom, observations.geom)) OR " +
      "(observations.private_latitude IS NOT NULL AND ST_Intersects(taxon_ranges.geom, ST_Point(observations.private_longitude, observations.private_latitude)))"
    )
  }
  
  # possibly radius in kilometers
  scope :near_point, Proc.new { |lat, lng, radius|
    lat = lat.to_f
    lng = lng.to_f
    radius = radius.to_f
    radius = 10.0 if radius == 0
    planetary_radius = PLANETARY_RADIUS / 1000 # km
    radius_degrees = radius / (2*Math::PI*planetary_radius) * 360.0
    
    where("ST_Distance(ST_SetSRID(ST_Point(?,?), -1), ST_SetSRID(geom, -1)) <= ?", lng.to_f, lat.to_f, radius_degrees)
  }
  
  # Has_property scopes
  scope :has_taxon, lambda { |taxon_id|
    if taxon_id.nil?
      where("taxon_id IS NOT NULL")
    else
      where("taxon_id IN (?)", taxon_id)
    end
  }
  scope :has_iconic_taxa, lambda { |iconic_taxon_ids|
    iconic_taxon_ids = [iconic_taxon_ids].flatten # make array if single
    if iconic_taxon_ids.include?(nil)
      where(
        "observations.iconic_taxon_id IS NULL OR observations.iconic_taxon_id IN (?)", 
        iconic_taxon_ids
      )
    elsif !iconic_taxon_ids.empty?
      where("observations.iconic_taxon_id IN (?)", iconic_taxon_ids)
    end
  }
  
  scope :has_geo, where("latitude IS NOT NULL AND longitude IS NOT NULL")
  scope :has_id_please, where("id_please IS TRUE")
  scope :has_photos, 
    select("DISTINCT observations.*").
    joins("JOIN observation_photos AS _op ON _op.observation_id = observations.id").
    where('_op.id IS NOT NULL')
  scope :has_quality_grade, lambda {|quality_grade|
    quality_grade = '' unless QUALITY_GRADES.include?(quality_grade)
    where("quality_grade = ?", quality_grade)
  }
  
  # Find observations by a taxon object.  Querying on taxa columns forces 
  # massive joins, it's a bit sluggish
  scope :of, lambda { |taxon|
    taxon = Taxon.find_by_id(taxon.to_i) unless taxon.is_a? Taxon
    return where("1 = 2") unless taxon
    joins(:taxon).where(
      "observations.taxon_id = ? OR taxa.ancestry LIKE '#{taxon.ancestry}/#{taxon.id}%'", 
      taxon
    )
  }
  
  scope :at_or_below_rank, lambda {|rank| 
    rank_level = Taxon::RANK_LEVELS[rank]
    joins(:taxon).where("taxa.rank_level <= ?", rank_level)
  }
  
  # Find observations by user
  scope :by, lambda { |user| where("observations.user_id = ?", user)}
  
  # Order observations by date and time observed
  scope :latest, order("observed_on DESC NULLS LAST, time_observed_at DESC NULLS LAST")
  scope :recently_added, order("observations.id DESC")
  
  # TODO: Make this work for any SQL order statement, including multiple cols
  scope :order_by, lambda { |order_sql|
    pieces = order_sql.split
    order_by = pieces[0]
    order = pieces[1] || 'ASC'
    extra = [pieces[2..-1]].flatten.join(' ')
    extra = "NULLS LAST" if extra.blank?
    options = {}
    case order_by
    when 'observed_on'
      order "observed_on #{order} #{extra}, time_observed_at #{order} #{extra}"
    when 'created_at'
      order "observations.id #{order} #{extra}"
    else
      order "#{order_by} #{order} #{extra}"
    end
  }
  
  def self.identifications(agreement)
    scope = Observation.scoped
    scope = scope.includes(:identifications)
    case agreement
    when 'most_agree'
      scope.where("num_identification_agreements > num_identification_disagreements")
    when 'some_agree'
      scope.where("num_identification_agreements > 0")
    when 'most_disagree'
      scope.where("num_identification_agreements < num_identification_disagreements")
    else
      scope
    end
  end
  
  # Time based named scopes
  scope :created_after, lambda { |time| where('created_at >= ?', time)}
  scope :created_before, lambda { |time| where('created_at <= ?', time)}
  scope :updated_after, lambda { |time| where('updated_at >= ?', time)}
  scope :updated_before, lambda { |time| where('updated_at <= ?', time)}
  scope :observed_after, lambda { |time| where('time_observed_at >= ?', time)}
  scope :observed_before, lambda { |time| where('time_observed_at <= ?', time)}
  scope :in_month, lambda {|month| where("EXTRACT(MONTH FROM observed_on) = ?", month)}
  
  scope :in_projects, lambda { |projects|
    projects = projects.split(',') if projects.is_a?(String)
    # NOTE using :include seems to trigger an erroneous eager load of 
    # observations that screws up sorting kueda 2011-07-22
    joins(:project_observations).where("project_observations.project_id IN (?)", projects)
  }
  
  scope :on, lambda {|date| where(Observation.conditions_for_date(:observed_on, date)) }
  
  scope :created_on, lambda {|date| where(Observation.conditions_for_date("observations.created_at", date))}
  
  scope :out_of_range, where(:out_of_range => true)
  scope :in_range, where(:out_of_range => false)
  scope :license, lambda {|license|
    if license == 'none'
      where("observations.license IS NULL")
    elsif LICENSE_CODES.include?(license)
      where(:license => license)
    else
      where("observations.license IS NOT NULL")
    end
  }
  
  scope :photo_license, lambda {|license|
    license = license.to_s
    scope = joins(:photos).scoped
    license_number = Photo.license_number_for_code(license)
    if license == 'none'
      scope.where("photos.license = 0")
    elsif LICENSE_CODES.include?(license)
      scope.where("photos.license = ?", license_number)
    else
      scope.where("photos.license > 0")
    end
  }

  scope :has_observation_field, lambda{|*args|
    field, value = args
    join_name = "ofv_#{field.is_a?(ObservationField) ? field.id : field}"
    scope = joins("LEFT OUTER JOIN observation_field_values #{join_name} ON #{join_name}.observation_id = observations.id").
      where("#{join_name}.observation_field_id = ?", field)
    scope = scope.where("#{join_name}.value = ?", value) unless value.blank?
    scope
  }
  
  def self.near_place(place)
    place = Place.find_by_id(place) unless place.is_a?(Place)
    if place.swlat
      Observation.in_bounding_box(place.swlat, place.swlng, place.nelat, place.nelng).scoped
    else
      Observation.near_point(place.latitude, place.longitude).scoped
    end
  end
  
  #
  # Uses scopes to perform a conditional search.
  # May be worth looking into squirrel or some other rails friendly search add on
  #
  def self.query(params = {})
    scope = self.scoped
    
    # support bounding box queries
     if (!params[:swlat].blank? && !params[:swlng].blank? && 
         !params[:nelat].blank? && !params[:nelng].blank?)
      scope = scope.in_bounding_box(params[:swlat], params[:swlng], params[:nelat], params[:nelng])
    elsif params[:lat] && params[:lng]
      scope = scope.near_point(params[:lat], params[:lng], params[:radius])
    end
    
    # has (boolean) selectors
    if params[:has]
      params[:has] = params[:has].split(',') if params[:has].is_a? String
      params[:has].select{|s| %w(geo id_please photos).include?(s)}.each do |prop|
        scope = case prop
          when 'geo' then scope.has_geo
          when 'id_please' then scope.has_id_please
          when 'photos' then scope.has_photos
        end
      end
    end
    scope = scope.identifications(params[:identifications]) if params[:identifications]
    scope = scope.has_iconic_taxa(params[:iconic_taxa]) if params[:iconic_taxa]
    scope = scope.order_by(params[:order_by]) if params[:order_by]
    
    scope = scope.has_quality_grade( params[:quality_grade]) if QUALITY_GRADES.include?(params[:quality_grade])
    
    if taxon = params[:taxon]
      scope = scope.of(taxon.is_a?(Taxon) ? taxon : taxon.to_i)
    elsif !params[:taxon_id].blank?
      scope = scope.of(params[:taxon_id].to_i)
    elsif !params[:taxon_name].blank?
      taxon_name = TaxonName.find_single(params[:taxon_name], :iconic_taxa => params[:iconic_taxa])
      scope = scope.of(taxon_name.try(:taxon))
    end
    scope = scope.by(params[:user_id]) if params[:user_id]
    scope = scope.in_projects(params[:projects]) if params[:projects]
    scope = scope.in_place(params[:place_id]) unless params[:place_id].blank?
    scope = scope.on(params[:on]) if params[:on]
    scope = scope.created_on(params[:created_on]) if params[:created_on]
    scope = scope.out_of_range if params[:out_of_range] == 'true'
    scope = scope.in_range if params[:out_of_range] == 'false'
    scope = scope.license(params[:license]) unless params[:license].blank?
    scope = scope.photo_license(params[:photo_license]) unless params[:photo_license].blank?
    unless params[:ofv_params].blank?
      params[:ofv_params].each do |k,v|
        scope = scope.has_observation_field(v[:observation_field], v[:value])
      end
    end

    if CONFIG.get(:site_only_observations) && params[:site].blank?
      scope = scope.where("observations.uri LIKE ?", "#{FakeView.root_url}%")
    elsif (site_bounds = CONFIG.get(:bounds)) && params[:swlat].blank?
      scope = scope.in_bounding_box(site_bounds['swlat'], site_bounds['swlng'], site_bounds['nelat'], site_bounds['nelng'])
    end
    
    # return the scope, we can use this for will_paginate calls like:
    # Observation.query(params).paginate()
    scope
  end
  # help_txt_for :species_guess, <<-DESC
  #   Type a name for what you saw.  It can be common or scientific, accurate 
  #   or just a placeholder. When you enter it, we'll try to look it up and find
  #   the matching species of higher level taxon.
  # DESC
  # 
  # instruction_for :place_guess, "Type the name of a place"
  # help_txt_for :place_guess, <<-DESC
  #   Enter the name of a place and we'll try to find where it is. If we find
  #   it, you can drag the map marker around to get more specific.
  # DESC
  
  def to_s
    "<Observation #{self.id}: #{to_plain_s}>"
  end
  
  def to_plain_s(options = {})
    s = self.species_guess.blank? ? 'something' : self.species_guess
    if options[:verb]
      s += options[:verb] == true ? " observed" : " #{options[:verb]}"
    end
    unless self.place_guess.blank? || options[:no_place_guess]
      s += " in #{self.place_guess}"
    end
    s += " on #{self.observed_on.to_s(:long)}" unless self.observed_on.blank?
    unless self.time_observed_at.blank? || options[:no_time]
      s += " at #{self.time_observed_at_in_zone.to_s(:plain_time)}"
    end
    s += " by #{self.user.try(:login)}" unless options[:no_user]
    s
  end
  
  def time_observed_at_utc
    time_observed_at.try(:utc)
  end
  
  def as_json(options = {})
    # don't use delete here, it will just remove the option for all 
    # subsequent records in an array
    options[:include] = if options[:include].is_a?(Hash)
      options[:include].map{|k,v| {k => v}}
    else
      [options[:include]].flatten.compact
    end
    options[:methods] ||= []
    options[:methods] << :time_observed_at_utc
    viewer = options[:viewer]
    viewer_id = viewer.is_a?(User) ? viewer.id : viewer.to_i
    options[:except] ||= []
    options[:except] += [:user_agent]
    if viewer_id != user_id && !options[:force_coordinate_visibility]
      options[:except] ||= []
      options[:except] += [:private_latitude, :private_longitude, :private_positional_accuracy, :geom]
      options[:except].uniq!
      options[:methods] << :coordinates_obscured
      options[:methods].uniq!
    end
    h = super(options)
    h.each do |k,v|
      h[k] = v.gsub(/<script.*script>/i, "") if v.is_a?(String)
    end
    h
  end
  
  def to_xml(options = {})
    options[:except] ||= []
    options[:except] += [:private_latitude, :private_longitude, :private_positional_accuracy, :geom]
    super(options)
  end
  
  #
  # Return a time from observed_on and time_observed_at
  #
  def datetime
    if observed_on && errors[:observed_on].blank?
      if time_observed_at
        Time.mktime(observed_on.year, 
                    observed_on.month, 
                    observed_on.day, 
                    time_observed_at.hour, 
                    time_observed_at.min, 
                    time_observed_at.sec, 
                    time_observed_at.zone)
      else
        Time.mktime(observed_on.year, 
                    observed_on.month, 
                    observed_on.day)
      end
    end
  end
  
  # Return time_observed_at in the observation's time zone
  def time_observed_at_in_zone
    self.time_observed_at.in_time_zone(self.time_zone)
  end
  
  #
  # Set all the time fields based on the contents of observed_on_string
  #
  def munge_observed_on_with_chronic
    if observed_on_string.blank?
      self.observed_on = nil
      self.time_observed_at = nil
      return true
    end
    date_string = observed_on_string.strip
    tz_abbrev_pattern = /\s\(?([A-Z]{3,})\)?$/ # ends with (PDT)
    tz_offset_pattern = /([+-]\d{4})$/ # contains -0800
    tz_js_offset_pattern = /(GMT)?[+-]\d{4}/ # contains GMT-0800
    tz_colon_offset_pattern = /(GMT|HSP)([+-]\d+:\d+)/ # contains (GMT-08:00)
    tz_failed_abbrev_pattern = /\(#{tz_colon_offset_pattern}\)/
    
    if date_string =~ /#{tz_js_offset_pattern} #{tz_failed_abbrev_pattern}/
      date_string = date_string.sub(tz_failed_abbrev_pattern, '').strip
    end
    
    if parsed_time_zone = ActiveSupport::TimeZone::CODES[date_string[tz_abbrev_pattern, 1]]
      date_string = observed_on_string.sub(tz_abbrev_pattern, '')
      date_string = date_string.sub(tz_js_offset_pattern, '').strip
      self.time_zone = parsed_time_zone.name if observed_on_string_changed?
    elsif (offset = date_string[tz_offset_pattern, 1]) && (parsed_time_zone = ActiveSupport::TimeZone[offset.to_f / 100])
      date_string = date_string.sub(tz_offset_pattern, '')
      self.time_zone = parsed_time_zone.name if observed_on_string_changed?
    elsif (offset = date_string[tz_js_offset_pattern, 1]) && (parsed_time_zone = ActiveSupport::TimeZone[offset.to_f / 100])
      date_string = date_string.sub(tz_js_offset_pattern, '')
      date_string = date_string.sub(/^(Sun|Mon|Tue|Wed|Thu|Fri|Sat)\s+/i, '')
      self.time_zone = parsed_time_zone.name if observed_on_string_changed?
    elsif (offset = date_string[tz_colon_offset_pattern, 2]) && (parsed_time_zone = ActiveSupport::TimeZone[offset.to_f])
      date_string = date_string.sub(tz_colon_offset_pattern, '')
      self.time_zone = parsed_time_zone.name if observed_on_string_changed?
    end
    
    date_string.sub!('T', ' ') if date_string =~ /\d{4}-\d{2}-\d{2}T/
    date_string.sub!(/(\d{2}:\d{2}:\d{2})\.\d+/, '\\1')
    
    # strip leading month if present
    date_string.sub!(/^[A-z]{3} ([A-z]{3})/, '\\1')
    
    # Set the time zone appropriately
    old_time_zone = Time.zone
    Time.zone = time_zone || user.try(:time_zone)
    Chronic.time_class = Time.zone
    
    begin
      # Start parsing...
      return true unless t = Chronic.parse(date_string)
    
      # Re-interpret future dates as being in the past
      if t > Time.now
        t = Chronic.parse(date_string, :context => :past)  
      end
    
      self.observed_on = t.to_date
    
      # try to determine if the user specified a time by ask Chronic to return
      # a time range. Time ranges less than a day probably specified a time.
      if tspan = Chronic.parse(date_string, :context => :past, :guess => false)
        # If tspan is less than a day and the string wasn't 'today', set time
        if tspan.width < 86400 && date_string.strip.downcase != 'today'
          self.time_observed_at = t
        else
          self.time_observed_at = nil
        end
      end
    rescue RuntimeError
      errors.add(:observed_on, 
        "was not recognized, some working examples are: yesterday, 3 years " +
        "ago, 5/27/1979, 1979-05-27 05:00. " +
        "(<a href='http://chronic.rubyforge.org/'>others</a>)")
      return true
    end
    
    # don't store relative observed_on_strings, or they will change
    # every time you save an observation!
    if date_string =~ /today|yesterday|ago|last|this|now|monday|tuesday|wednesday|thursday|friday|saturday|sunday/i
      self.observed_on_string = self.observed_on.to_s
      if self.time_observed_at
        self.observed_on_string = self.time_observed_at.strftime("%Y-%m-%d %H:%M:%S")
      end
    end
    
    # Set the time zone back the way it was
    Time.zone = old_time_zone
    true
  end
  
  #
  # Adds, updates, or destroys the identification corresponding to the taxon
  # the user selected.
  #
  def update_identifications
    return true if @skip_identifications
    return true unless taxon_id_changed?
    owners_ident = identifications.where(:user_id => user_id).order("id asc").last
    
    # If there's a taxon we need to make sure the owner's ident agrees
    if taxon && (owners_ident.blank? || owners_ident.taxon_id != taxon.id)
      # If the owner doesn't have an identification for this obs, make one
      owners_ident = self.identifications.build(:user => user, :taxon => taxon, :observation => self)
      owners_ident.skip_observation = true
    elsif taxon.blank? && owners_ident && owners_ident.current?
      owners_ident.skip_observation = true
      owners_ident.update_attributes(:current => false)
    end
    
    update_stats(:skip_save => true)
    
    true
  end

  # Override nested obs field values attributes setter to ensure that field
  # values get added even if existing field values have been destroyed (e.g.
  # two windows). Also updating existing OFV of same OF name if id not 
  # specified
  def observation_field_values_attributes=(attributes)
    attr_array = attributes.is_a?(Hash) ? attributes.values : attributes
    attr_array.each_with_index do |v,i|
      if v["id"].blank?
        if existing = observation_field_values.where(:observation_field_id => v["name"]).first
          attr_array[i]["id"] = existing.id
        end
      elsif !ObservationFieldValue.where("id = ?", v["id"]).exists?
        attr_array[i].delete("id")
      end
    end
    assign_nested_attributes_for_collection_association(:observation_field_values, attr_array, mass_assignment_options)
  end
  
  #
  # Update the user's lists with changes to this observation's taxon
  #
  # If the observation is the last_observation in any of the user's lists,
  # then the last_observation should be reset to another observation.
  #
  def refresh_lists
    return true if @skip_refresh_lists
    return true unless taxon_id_changed?
    
    # Update the observation's current taxon and/or a previous one that was
    # just removed/changed
    target_taxa = [
      taxon, 
      Taxon.find_by_id(@old_observation_taxon_id)
    ].compact.uniq
    
    # Don't refresh all the lists if nothing changed
    return true if target_taxa.empty?
    
    unless Delayed::Job.where("handler LIKE '%''List%refresh_with_observation% #{id}\n%'").exists?
      List.delay(:priority => USER_INTEGRITY_PRIORITY).refresh_with_observation(id, :taxon_id => taxon_id, 
        :taxon_id_was => taxon_id_was, :user_id => user_id, :created_at => created_at,
        :skip_subclasses => true)
    end
    unless Delayed::Job.where("handler LIKE '%LifeList%refresh_with_observation% #{id}\n%'").exists?
      LifeList.delay(:priority => USER_INTEGRITY_PRIORITY).refresh_with_observation(id, :taxon_id => taxon_id, 
        :taxon_id_was => taxon_id_was, :user_id => user_id, :created_at => created_at)
    end
    unless Delayed::Job.where("handler LIKE '%ProjectList%refresh_with_observation% #{id}\n%'").exists?
      ProjectList.delay(:priority => USER_INTEGRITY_PRIORITY).refresh_with_observation(id, :taxon_id => taxon_id, 
        :taxon_id_was => taxon_id_was, :user_id => user_id, :created_at => created_at)
    end
    
    # Reset the instance var so it doesn't linger around
    @old_observation_taxon_id = nil
    true
  end
  
  def refresh_check_lists
    refresh_needed = (georeferenced? || was_georeferenced?) && 
      (taxon_id || taxon_id_was) && 
      (quality_grade_changed? || taxon_id_changed? || latitude_changed? || longitude_changed? || observed_on_changed?)
    return true unless refresh_needed
    return true if Delayed::Job.where("handler LIKE '%CheckList%refresh_with_observation% #{id}\n%'").exists?
    CheckList.delay(:priority => INTEGRITY_PRIORITY).refresh_with_observation(id, :taxon_id => taxon_id, 
      :taxon_id_was  => taxon_id_changed? ? taxon_id_was : nil,
      :latitude_was  => (latitude_changed? || longitude_changed?) ? latitude_was : nil,
      :longitude_was => (latitude_changed? || longitude_changed?) ? longitude_was : nil,
      :new => id_was.blank?)
    true
  end
  
  # Because it has to be slightly different, in that the taxon of a destroyed
  # obs shouldn't be removed by default from life lists (maybe you've seen it
  # in the past, but you don't have any other obs), but those listed_taxa of
  # this taxon should have their last_observation reset.
  #
  def refresh_lists_after_destroy
    return true if @skip_refresh_lists
    return true unless taxon
    List.delay(:priority => USER_INTEGRITY_PRIORITY).refresh_with_observation(id, :taxon_id => taxon_id, 
      :taxon_id_was => taxon_id_was, :user_id => user_id, :created_at => created_at,
      :skip_subclasses => true)
    LifeList.delay(:priority => USER_INTEGRITY_PRIORITY).refresh_with_observation(id, :taxon_id => taxon_id, 
      :taxon_id_was => taxon_id_was, :user_id => user_id, :created_at => created_at)
    true
  end
  
  #
  # Preserve the old taxon id if the taxon has changed so we know to update
  # that taxon in the user's lists after_save
  #
  def keep_old_taxon_id
    @old_observation_taxon_id = taxon_id_was if taxon_id_changed?
    true
  end
  
  #
  # Remove any instructional text that may have been submitted with the form.
  #
  def scrub_instructions_before_save
    self.attributes.each do |attr_name, value|
      if Observation.instructions[attr_name.to_sym] and value and
        Observation.instructions[attr_name.to_sym] == value
        write_attribute(attr_name.to_sym, nil)
      end
    end
  end
  
  #
  # Set the iconic taxon if it hasn't been set
  #
  def set_iconic_taxon
    return true unless self.taxon_id_changed?
    if taxon
      self.iconic_taxon_id ||= taxon.iconic_taxon_id
    else
      self.iconic_taxon_id = nil
    end
    true
  end
  
  #
  # Trim whitespace around species guess
  #
  def strip_species_guess
    self.species_guess.strip! unless species_guess.nil?
    true
  end
  
  #
  # Set the time_zone of this observation if not already set
  #
  def set_time_zone
    self.time_zone = nil if time_zone.blank?
    self.time_zone ||= user.time_zone if user && !user.time_zone.blank?
    self.time_zone ||= Time.zone.try(:name) unless time_observed_at.blank?
    self.time_zone ||= 'UTC'
    true
  end
  
  #
  # Cast lat and lon so they will (hopefully) pass the numericallity test
  #
  def cast_lat_lon
    # self.latitude = latitude.to_f unless latitude.blank?
    # self.longitude = longitude.to_f unless longitude.blank?
    true
  end  
  
  #
  # Force time_observed_at into the time zone
  #
  def set_time_in_time_zone
    return true if time_observed_at.blank? || time_zone.blank?
    return true unless time_observed_at_changed? || time_zone_changed?
    
    # Render the time as a string
    time_s = time_observed_at_before_type_cast
    unless time_s.is_a? String
      time_s = time_observed_at_before_type_cast.strftime("%Y-%m-%d %H:%M:%S")
    end
    
    # Get the time zone offset as a string and append it
    offset_s = Time.parse(time_s).in_time_zone(time_zone).formatted_offset(false)
    time_s += " #{offset_s}"
    
    self.time_observed_at = Time.parse(time_s)
    true
  end
  
  
  def lsid
    "lsid:inaturalist.org:observations:#{id}"
  end
  
  def component_cache_key(options = {})
    Observation.component_cache_key(id, options)
  end
  
  def self.component_cache_key(id, options = {})
    key = "obs_comp_#{id}"
    key += "_"+options.map{|k,v| "#{k}-#{v}"}.join('_') unless options.blank?
    key
  end
  
  def num_identifications_by_others
    identifications.select{|i| i.user_id != user_id}.size
  end
  
  ##### Rules ###############################################################
  #
  # This section contains all of the rules that can be used for list creation
  # or goal completion
  
  class << self # this just prevents me from having to write def self.*
    
    # Written for the Goals framework.
    # Accepts two parameters, the first is 'thing' from GoalRule,
    # the second is an array created when the GoalRule splits on pipes "|"
    def within_the_first_n_contributions?(observation, args)
      return false unless observation.instance_of? self
      return true if count <= args[0].to_i
      find(:all,
           :select => "id",
           :order => "created_at ASC",
           :limit => args[0]).include?(observation)
    end
  end
  
  #
  # Checks whether this observation has been flagged
  #
  def flagged?
    self.flags.select { |f| not f.resolved? }.size > 0
  end
  
  def georeferenced?
    (latitude? && longitude?) || (private_latitude? && private_longitude?)
  end
  
  def was_georeferenced?
    (latitude_was && longitude_was) || (private_latitude_was && private_longitude_was)
  end
  
  def quality_metric_score(metric)
    quality_metrics.all unless quality_metrics.loaded?
    metrics = quality_metrics.select{|qm| qm.metric == metric}
    return nil if metrics.blank?
    metrics.select{|qm| qm.agree?}.size.to_f / metrics.size
  end
  
  def community_supported_id?
    num_identification_agreements.to_i > 0 && num_identification_agreements > num_identification_disagreements
  end
  
  def quality_metrics_pass?
    QualityMetric::METRICS.each do |metric|
      score = quality_metric_score(metric)
      return false if score && score < 0.5
    end
    true
  end
  
  def research_grade?
    georeferenced? && community_supported_id? && quality_metrics_pass? && observed_on? && photos?
  end
  
  def photos?
    observation_photos.exists?
  end
  
  def casual_grade?
    !research_grade?
  end
  
  def set_quality_grade(options = {})
    if options[:force] || quality_grade_changed? || latitude_changed? || longitude_changed? || observed_on_changed? || taxon_id_changed?
      self.quality_grade = get_quality_grade
    end
    true
  end
  
  def self.set_quality_grade(id)
    return unless observation = Observation.find_by_id(id)
    observation.set_quality_grade(:force => true)
    observation.save
    if observation.quality_grade_changed? && !Delayed::Job.where("handler LIKE '%CheckList%refresh_with_observation% #{id}\n%'").exists?
      CheckList.delay(:priority => INTEGRITY_PRIORITY).refresh_with_observation(observation.id, :taxon_id => observation.taxon_id)
    end
    observation.quality_grade
  end
  
  def get_quality_grade
    research_grade? ? RESEARCH_GRADE : CASUAL_GRADE
  end
  
  def coordinates_obscured?
    !private_latitude.blank? || !private_longitude.blank?
  end
  alias :coordinates_obscured :coordinates_obscured?
  
  def geoprivacy_private?
    geoprivacy == PRIVATE
  end
  
  def geoprivacy_obscured?
    geoprivacy == OBSCURED
  end
  
  def coordinates_viewable_by?(user)
    return true unless coordinates_obscured?
    user = User.find_by_id(user) unless user.is_a?(User)
    return false unless user
    return true if user_id == user.id
    return true if user.project_users.curators.exists?(["project_id IN (?)", project_ids])
    false
  end
  
  def reset_private_coordinates_if_coordinates_changed
    if (latitude_changed? || longitude_changed?)
      self.private_latitude = nil
      self.private_longitude = nil
    end
    true
  end
  
  def obscure_coordinates_for_geoprivacy
    self.geoprivacy = nil if geoprivacy.blank?
    return true if geoprivacy.blank? && !geoprivacy_changed?
    case geoprivacy
    when PRIVATE
      obscure_coordinates(M_TO_OBSCURE_THREATENED_TAXA) unless coordinates_obscured?
      self.latitude, self.longitude = [nil, nil]
    when OBSCURED
      obscure_coordinates(M_TO_OBSCURE_THREATENED_TAXA) unless coordinates_obscured?
    else
      unobscure_coordinates
    end
    true
  end
  
  def obscure_coordinates_for_threatened_taxa
    obscuring_needed_for_taxon = taxon && 
      taxon.species_or_lower? && 
      (taxon.threatened? || (taxon.parent && taxon.parent.threatened?))

    if obscuring_needed_for_taxon && georeferenced? && !coordinates_obscured?
      obscure_coordinates(M_TO_OBSCURE_THREATENED_TAXA)
    elsif geoprivacy.blank? && !obscuring_needed_for_taxon
      unobscure_coordinates
    end
    true
  end
  
  def obscure_coordinates(distance = M_TO_OBSCURE_THREATENED_TAXA)
    self.place_guess = obscured_place_guess
    return if latitude.blank? || longitude.blank?
    if latitude_changed? || longitude_changed?
      self.private_latitude = latitude
      self.private_longitude = longitude
    else
      self.private_latitude ||= latitude
      self.private_longitude ||= longitude
    end
    self.latitude, self.longitude = random_neighbor_lat_lon(private_latitude, private_longitude, distance)
  end
  
  def lat_lon_in_place_guess?
    !place_guess.blank? && place_guess !~ /[a-cf-mo-rt-vx-z]/i && !place_guess.scan(COORDINATE_REGEX).blank?
  end
  
  def obscured_place_guess
    return place_guess if place_guess.blank?
    return nil if lat_lon_in_place_guess?
    place_guess.sub(/^[\d\-]+\s+/, '')
  end
  
  def unobscure_coordinates
    return unless coordinates_obscured?
    return unless geoprivacy.blank?
    self.latitude = private_latitude
    self.longitude = private_longitude
    self.private_latitude = nil
    self.private_longitude = nil
  end
  
  def iconic_taxon_name
    Taxon::ICONIC_TAXA_BY_ID[iconic_taxon_id].try(:name)
  end
  
  def self.obscure_coordinates_for_observations_of(taxon)
    taxon = Taxon.find_by_id(taxon) unless taxon.is_a?(Taxon)
    return unless taxon
    Observation.find_observations_of(taxon) do |o|
      o.obscure_coordinates
      Observation.update_all({
        :place_guess => o.place_guess,
        :latitude => o.latitude,
        :longitude => o.longitude,
        :private_latitude => o.private_latitude,
        :private_longitude => o.private_longitude,
      }, {:id => o.id})
    end
  end
  
  def self.unobscure_coordinates_for_observations_of(taxon)
    taxon = Taxon.find_by_id(taxon) unless taxon.is_a?(Taxon)
    return unless taxon
    Observation.find_observations_of(taxon) do |o|
      o.unobscure_coordinates
      Observation.update_all({
        :latitude => o.latitude,
        :longitude => o.longitude,
        :private_latitude => o.private_latitude,
        :private_longitude => o.private_longitude,
      }, {:id => o.id})
    end
  end
  
  def self.find_observations_of(taxon)
    options = {
      :include => :taxon,
      :conditions => [
        "observations.taxon_id = ? OR taxa.ancestry LIKE '#{taxon.ancestry}/#{taxon.id}%'", 
        taxon
      ]
    }
    Observation.find_each(options) do |o|
      yield(o)
    end
  end
  
  
  ##### Validations #########################################################
  #
  # Make sure the observation is not in the future.
  #
  def must_be_in_the_past
  
    unless observed_on.nil? || observed_on <= Date.today
      errors.add(:observed_on, "can't be in the future")
    end
    true
  end
  
  #
  # Make sure the observation resolves to a single day.  Right now we don't
  # store ambiguity...
  #
  def must_not_be_a_range
    return if observed_on_string.blank?
    
    is_a_range = false
    begin  
      if tspan = Chronic.parse(observed_on_string, :context => :past, :guess => false)
        is_a_range = true if tspan.width.seconds > 1.day.seconds
      end
    rescue RuntimeError
      errors.add(:observed_on, 
        "was not recognized, some working examples are: yesterday, 3 years " +
        "ago, 5/27/1979, 1979-05-27 05:00. " +
        "(<a href='http://chronic.rubyforge.org/'>others</a>)"
      ) 
      return
    end
    
    # Special case: dates like '2004', which ordinarily resolve to today at 
    # 8:04pm
    observed_on_int = observed_on_string.gsub(/[^\d]/, '').to_i
    if observed_on_int > 1900 && observed_on_int <= Date.today.year
      is_a_range = true
    end
    
    if is_a_range
      errors.add(:observed_on, "must be a single day, not a range")
    end
  end
  
  def set_taxon_from_taxon_name
    return true if @taxon_name.blank?
    return true if taxon_id
    self.taxon_id = single_taxon_id_for_name(@taxon_name)
    true
  end
  
  def set_taxon_from_species_guess
    return true unless species_guess_changed? && taxon_id.blank?
    return true if species_guess.blank?
    self.taxon_id = single_taxon_id_for_name(species_guess)
    true
  end
  
  def single_taxon_for_name(name)
    Taxon.single_taxon_for_name(name)
  end
  
  def single_taxon_id_for_name(name)
    Taxon.single_taxon_for_name(name).try(:id)
  end
  
  def set_latlon_from_place_guess
    return true unless latitude.blank? && longitude.blank?
    return true if place_guess.blank?
    return true if place_guess =~ /[a-cf-mo-rt-vx-z]/i # ignore anything with word chars other than NSEW
    return true unless place_guess.strip =~ /[.+,\s.+]/ # ignore anything without a legit separator
    matches = place_guess.strip.scan(COORDINATE_REGEX).flatten
    return true if matches.blank?
    case matches.size
    when 2 # decimal degrees
      self.latitude, self.longitude = matches
    when 4 # decimal minutes
      self.latitude = matches[0].to_i + matches[1].to_f/60.0
      self.longitude = matches[3].to_i + matches[4].to_f/60.0
    when 6 # degrees / minutes / seconds
      self.latitude = matches[0].to_i + matches[1].to_i/60.0 + matches[2].to_f/60/60
      self.longitude = matches[3].to_i + matches[4].to_i/60.0 + matches[5].to_f/60/60
    end
    self.latitude *= -1 if latitude.to_f > 0 && place_guess =~ /s/i
    self.longitude *= -1 if longitude.to_f > 0 && place_guess =~ /w/i
    true
  end
  
  def set_geom_from_latlon
    if longitude.blank? || latitude.blank?
      self.geom = nil
    elsif longitude_changed? || latitude_changed?
      self.geom = Point.from_x_y(longitude, latitude)
    end
    true
  end
  
  def set_license
    return true if license_changed? && license.blank?
    self.license ||= user.preferred_observation_license
    self.license = nil unless LICENSE_CODES.include?(license)
    true
  end

  def trim_user_agent
    return true if user_agent.blank?
    self.user_agent = user_agent[0..254]
    true
  end
  
  def update_out_of_range_later
    if taxon_id_changed? && taxon.blank?
      update_out_of_range
    elsif latitude_changed? || private_latitude_changed? || taxon_id_changed?
      delay.update_out_of_range
    end
    true
  end
  
  def update_out_of_range
    set_out_of_range
    Observation.update_all(["out_of_range = ?", out_of_range], ["id = ?", id])
  end
  
  def set_out_of_range
    if taxon_id.blank? || !georeferenced? || !TaxonRange.exists?(["taxon_id = ?", taxon_id])
      self.out_of_range = nil
      return
    end
    
    # buffer the point to accomodate simplified or slightly inaccurate ranges
    buffer_degrees = OUT_OF_RANGE_BUFFER / (2*Math::PI*Observation::PLANETARY_RADIUS) * 360.0
    
    self.out_of_range = if coordinates_obscured?
      TaxonRange.exists?([
        "taxon_ranges.taxon_id = ? AND ST_Distance(taxon_ranges.geom, ST_Point(?,?)) > ?",
        taxon_id, private_longitude, private_latitude, buffer_degrees
      ])
    else
      TaxonRange.count(
        :from => "taxon_ranges, observations",
        :conditions => [
          "taxon_ranges.taxon_id = ? AND observations.id = ? AND ST_Distance(taxon_ranges.geom, observations.geom) > ?",
          taxon_id, id, buffer_degrees]
      ) > 0
    end
  end

  def set_uri
    if uri.blank?
      Observation.update_all(["uri = ?", FakeView.observation_url(id)], ["id = ?", id])
    end
    true
  end
  
  def update_default_license
    return true unless [true, "1", "true"].include?(@make_license_default)
    user.update_attribute(:preferred_observation_license, license)
    true
  end
  
  def update_all_licenses
    return true unless [true, "1", "true"].include?(@make_licenses_same)
    Observation.update_all(["license = ?", license], ["user_id = ?", user_id])
    true
  end
  
  def update_attributes(attributes)
    # hack around a weird android bug
    attributes.delete(:iconic_taxon_name)
    
    # MASS_ASSIGNABLE_ATTRIBUTES.each do |a|
    #   self.send("#{a}=", attributes.delete(a.to_s)) if attributes.has_key?(a.to_s)
    #   self.send("#{a}=", attributes.delete(a)) if attributes.has_key?(a)
    # end
    super(attributes)
  end
  
  def license_name
    return nil if license.blank?
    s = "Creative Commons "
    s += LICENSES.detect{|row| row.first == license}.try(:[], 1).to_s
    s
  end
  
  # I'm not psyched about having this stuff here, but it makes generating 
  # more compact JSON a lot easier.
  include ObservationsHelper
  include ActionView::Helpers::SanitizeHelper
  include ActionView::Helpers::TextHelper
  # include ActionController::UrlWriter
  include Rails.application.routes.url_helpers
  
  def image_url
    observation_image_url(self, :size => "medium")
  end
  
  def obs_image_url
    image_url
  end
  
  def short_description
    short_observation_description(self)
  end
  
  def scientific_name
    taxon.scientific_name.name if taxon && taxon.scientific_name
  end
  
  def common_name
    taxon.common_name.name if taxon && taxon.common_name
  end
  
  def url
    observation_url(self, ActionMailer::Base.default_url_options)
  end
  
  def user_login
    user.login
  end
  
  def update_stats(options = {})
    idents = [self.identifications.to_a, options[:include]].flatten.compact.uniq
    if taxon_id.blank?
      num_agreements    = 0
      num_disagreements = 0
    else
      num_agreements    = idents.select{|ident| ident.current? && ident.is_agreement?(:observation => self)}.size
      num_disagreements = idents.select{|ident| ident.current? && ident.is_disagreement?(:observation => self)}.size
    end
    
    # Kinda lame, but Observation#get_quality_grade relies on these numbers
    self.num_identification_agreements = num_agreements
    self.num_identification_disagreements = num_disagreements
    new_quality_grade = get_quality_grade
    self.quality_grade = new_quality_grade
    
    if !options[:skip_save] && (num_identification_agreements_changed? || num_identification_disagreements_changed? || quality_grade_changed?)
      Observation.update_all(
        ["num_identification_agreements = ?, num_identification_disagreements = ?, quality_grade = ?", 
          num_agreements, num_disagreements, new_quality_grade], 
        "id = #{id}")
      refresh_check_lists
    end
  end
  
  def self.update_stats_for_observations_of(taxon)
    taxon = Taxon.find_by_id(taxon) unless taxon.is_a?(Taxon)
    return unless taxon
    Rails.logger.info "[INFO #{Time.now}] Observation.update_stats_for_observations_of(#{taxon})"
    conditions = taxon.descendant_conditions
    conditions[0] = "#{conditions[0]} OR observations.taxon_id = ?"
    conditions << taxon.id
    Observation.do_in_batches(:include => :taxon, :conditions => conditions) do |o|
      o.update_stats
    end
    Rails.logger.info "[INFO #{Time.now}] Finished Observation.update_stats_for_observations_of(#{taxon})"
  end
  
  def random_neighbor_lat_lon(lat, lon, max_distance, radius = PLANETARY_RADIUS)
    latrads = lat.to_f / DEGREES_PER_RADIAN
    lonrads = lon.to_f / DEGREES_PER_RADIAN
    max_distance = max_distance / radius
    random_distance = Math.acos(rand * (Math.cos(max_distance) - 1) + 1)
    random_bearing = 2 * Math::PI * rand
    new_latrads = Math.asin(
      Math.sin(latrads)*Math.cos(random_distance) + 
      Math.cos(latrads)*Math.sin(random_distance)*Math.cos(random_bearing)
    )
    new_lonrads = lonrads + 
      Math.atan2(
        Math.sin(random_bearing)*Math.sin(random_distance)*Math.cos(latrads), 
        Math.cos(random_distance)-Math.sin(latrads)*Math.sin(latrads)
      )
    [new_latrads * DEGREES_PER_RADIAN, new_lonrads * DEGREES_PER_RADIAN]
  end
  
  def places
    return [] unless georeferenced?
    lat = private_latitude || latitude
    lon = private_longitude || longitude
    acc = private_positional_accuracy || positional_accuracy
    candidates = Place.containing_lat_lng(lat, lon).sort_by{|p| p.bbox_area}

    # at present we use PostGIS GEOMETRY types, which are a bit stupid about
    # things crossing the dateline, so we need to do an app-layer check.
    # Converting to the GEOGRAPHY type would solve this, in theory.
    # Unfrotinately this does NOT solve the problem of failing to select 
    # legit geoms that cross the dateline. GEOGRAPHY would solve that too.
    candidates.select{|p| p.bbox_contains_lat_lng_acc?(lat, lon, acc)}
  end
  
  def public_places
    all_places = places
    return if all_places.blank?
    return all_places unless coordinates_obscured?
    
    # for obscured coordinates only return default place types that weren't
    # made by users. This is not ideal, but hopefully will get around honey
    # pots.
    system_places(:places => all_places)
  end

  def system_places(options = {})
    all_places = options[:places] || places
    all_places.select do |p| 
      p.user_id.blank? &&
        [Place::PLACE_TYPE_CODES['Country'],
          Place::PLACE_TYPE_CODES['State'],
          Place::PLACE_TYPE_CODES['County'],
          Place::PLACE_TYPE_CODES['Open Space']].include?(p.place_type)
    end
  end

  def taxon_and_ancestors
    taxon ? taxon.self_and_ancestors.to_a : []
  end
  
  def mobile?
    return false unless user_agent
    MOBILE_APP_USER_AGENT_PATTERNS.each do |pattern|
      return true if user_agent =~ pattern
    end
    false
  end
  
  def device_name
    return "unknown" unless user_agent
    if user_agent =~ ANDROID_APP_USER_AGENT_PATTERN
      "iNaturalist Android App"
    elsif user_agent =~ FISHTAGGER_APP_USER_AGENT_PATTERN
      "Fishtagger iPhone App"
    elsif user_agent =~ IPHONE_APP_USER_AGENT_PATTERN
      "iNaturalist iPhone App"
    else
      "web browser"
    end
  end
  
  def device_url
    return unless user_agent
    if user_agent =~ FISHTAGGER_APP_USER_AGENT_PATTERN
      "http://itunes.apple.com/us/app/fishtagger/id582724178?mt=8"
    elsif user_agent =~ IPHONE_APP_USER_AGENT_PATTERN
      "http://itunes.apple.com/us/app/inaturalist/id421397028?mt=8"
    elsif user_agent =~ ANDROID_APP_USER_AGENT_PATTERN
      "https://market.android.com/details?id=org.inaturalist.android"
    else
      "/"
    end
  end
  
  def owners_identification
    if identifications.loaded?
      identifications.detect {|ident| ident.user_id == user_id && ident.current?}
    else
      identifications.current.by(user_id).last
    end
  end
  
  # Required for use of the sanitize method in
  # ObservationsHelper#short_observation_description
  def self.white_list_sanitizer
    @white_list_sanitizer ||= HTML::WhiteListSanitizer.new
  end
  
  def self.expire_components_for(taxon)
    taxon = Taxon.find_by_id(taxon) unless taxon.is_a?(Taxon)
    Observation.of(taxon).find_each do |o|
      ctrl = ActionController::Base.new
      ctrl.expire_fragment(o.component_cache_key)
      ctrl.expire_fragment(o.component_cache_key(:for_owner => true))
    end
  end

  def self.update_for_taxon_change(taxon_change, taxon, options = {}, &block)
    input_taxon_ids = taxon_change.input_taxa.map(&:id)
    scope = Observation.where("observations.taxon_id IN (?)", input_taxon_ids).scoped
    scope = scope.by(options[:user]) if options[:user]
    scope = scope.where("observations.id IN (?)", options[:records]) unless options[:records].blank?
    scope = scope.includes(:user)
    scope.find_each do |observation|
      Identification.create(:user => observation.user, :observation => observation, :taxon => taxon, :taxon_change => taxon_change)
      yield(observation) if block_given?
    end
  end

  def self.generate_csv_for(record, options = {})
    fname = options[:fname] || "#{record.to_param}-observations.csv"
    fpath = options[:path] || File.join(options[:dir] || Dir::tmpdir, fname)
    tmp_path = File.join(Dir::tmpdir, fname)
    FileUtils.mkdir_p File.dirname(tmp_path), :mode => 0755

    columns = CSV_COLUMNS
    if record.is_a?(User) && record != options[:user]
      columns = columns.select{|c| c !~ /^private_/} unless record == options[:user]
    end
    columns -= %w(user_id user_login) if record.is_a?(User)
    CSV.open(tmp_path, 'w') do |csv|
      csv << columns
      record.observations.includes(:taxon, {:observation_field_values => :observation_field}).find_each do |observation|
        csv << columns.map{|c| observation.send(c)}
      end
    end
    FileUtils.mkdir_p File.dirname(fpath), :mode => 0755
    if tmp_path != fpath
      FileUtils.mv tmp_path, fpath
    end
    fpath
  end

  def self.generate_csv_for_cache_key(record, options = {})
    "#{record.class.name.underscore}_#{record.id}"
  end
  
end
