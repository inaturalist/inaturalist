#encoding: utf-8
class Observation < ActiveRecord::Base

  include ActsAsElasticModel

  has_subscribers :to => {
    :comments => {:notification => "activity", :include_owner => true},
    :identifications => {:notification => "activity", :include_owner => true}
  }
  notifies_subscribers_of :user, :notification => "created_observations",
    :queue_if => lambda { |observation| !observation.bulk_import }
  notifies_subscribers_of :public_places, :notification => "new_observations", 
    :on => :create,
    :queue_if => lambda {|observation|
      observation.georeferenced? && !observation.bulk_import
    },
    :if => lambda {|observation, place, subscription|
      return false unless observation.georeferenced?
      return true if subscription.taxon_id.blank?
      return false if observation.taxon.blank?
      observation.taxon.ancestor_ids.include?(subscription.taxon_id)
    }
  notifies_subscribers_of :taxon_and_ancestors, :notification => "new_observations", 
    :queue_if => lambda {|observation| !observation.taxon_id.blank? && !observation.bulk_import},
    :if => lambda {|observation, taxon, subscription|
      return true if observation.taxon_id == taxon.id
      return false if observation.taxon.blank?
      observation.taxon.ancestor_ids.include?(subscription.resource_id)
    }
  acts_as_taggable
  acts_as_votable
  acts_as_spammable fields: [ :description ],
                    comment_type: "item-description",
                    automated: false
  include Ambidextrous
  
  # Set to true if you want to skip the expensive updating of all the user's
  # lists after saving.  Useful if you're saving many observations at once and
  # you want to update lists in a batch
  attr_accessor :skip_refresh_lists, :skip_refresh_check_lists, :skip_identifications, :bulk_import
  
  # Set if you need to set the taxon from a name separate from the species 
  # guess
  attr_accessor :taxon_name
  
  # licensing extras
  attr_accessor :make_license_default
  attr_accessor :make_licenses_same
  
  # coordinate system
  attr_accessor :coordinate_system
  attr_accessor :geo_x
  attr_accessor :geo_y

  attr_accessor :twitter_sharing
  attr_accessor :facebook_sharing

  attr_accessor :captive_flag
  attr_accessor :force_quality_metrics

  # custom project field errors
  attr_accessor :custom_field_errors
  
  MASS_ASSIGNABLE_ATTRIBUTES = [:make_license_default, :make_licenses_same]
  
  M_TO_OBSCURE_THREATENED_TAXA = 10000
  OUT_OF_RANGE_BUFFER = 5000 # meters
  PLANETARY_RADIUS = 6370997.0
  DEGREES_PER_RADIAN = 57.2958
  FLOAT_REGEX = /[-+]?[0-9]*\.?[0-9]+/
  COORDINATE_REGEX = /[^\d\,]*?(#{FLOAT_REGEX})[^\d\,]*?/
  LAT_LON_SEPARATOR_REGEX = /[\,\s]\s*/
  LAT_LON_REGEX = /#{COORDINATE_REGEX}#{LAT_LON_SEPARATOR_REGEX}#{COORDINATE_REGEX}/

  OPEN = "open"
  PRIVATE = "private"
  OBSCURED = "obscured"
  GEOPRIVACIES = [OBSCURED, PRIVATE]
  GEOPRIVACY_DESCRIPTIONS = {
    OPEN => :open_description,
    OBSCURED => :obscured_description, 
    PRIVATE => :private_description
  }
  CASUAL_GRADE = "casual"
  RESEARCH_GRADE = "research"
  QUALITY_GRADES = [CASUAL_GRADE, RESEARCH_GRADE]

  COMMUNITY_TAXON_SCORE_CUTOFF = (2.0 / 3)
  
  LICENSES = [
    ["CC-BY", :cc_by_name, :cc_by_description],
    ["CC-BY-NC", :cc_by_nc_name, :cc_by_nc_description],
    ["CC-BY-SA", :cc_by_sa_name, :cc_by_sa_description],
    ["CC-BY-ND", :cc_by_nd_name, :cc_by_nd_description],
    ["CC-BY-NC-SA",:cc_by_nc_sa_name, :cc_by_nc_sa_description],
    ["CC-BY-NC-ND", :cc_by_nc_nd_name, :cc_by_nc_nd_description]
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
    "oauth_application_id"
  ]
  BASIC_COLUMNS = [
    "id", 
    "observed_on_string",
    "observed_on", 
    "time_observed_at",
    "time_zone",
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
    "id_please",
    "num_identification_agreements",
    "num_identification_disagreements",
    "captive_cultivated",
    "oauth_application_id"
  ]
  GEO_COLUMNS = [
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
    "place_town_name",
    "place_county_name",
    "place_state_name",
    "place_country_name"
  ]
  TAXON_COLUMNS = [
    "species_guess",
    "scientific_name", 
    "common_name", 
    "iconic_taxon_name",
    "taxon_id"
  ]
  EXTRA_TAXON_COLUMNS = %w(
    kingdom
    phylum
    subphylum
    superclass
    class
    subclass
    superorder
    order
    suborder
    superfamily
    family
    subfamily
    supertribe
    tribe
    subtribe
    genus
    genushybrid
    species
    hybrid
    subspecies
    variety
    form
  ).map{|r| "taxon_#{r}_name"}.compact
  ALL_EXPORT_COLUMNS = (CSV_COLUMNS + BASIC_COLUMNS + GEO_COLUMNS + TAXON_COLUMNS + EXTRA_TAXON_COLUMNS).uniq

  preference :community_taxon, :boolean, :default => nil
  WGS84_PROJ4 = "+proj=longlat +ellps=WGS84 +datum=WGS84 +no_defs"
  
  belongs_to :user, :counter_cache => true
  belongs_to :taxon
  belongs_to :community_taxon, :class_name => 'Taxon'
  belongs_to :iconic_taxon, :class_name => 'Taxon', 
                            :foreign_key => 'iconic_taxon_id'
  belongs_to :oauth_application
  belongs_to :site, :inverse_of => :observations
  has_many :observation_photos, -> { order("id asc") }, :dependent => :destroy, :inverse_of => :observation
  has_many :photos, :through => :observation_photos
  
  # note last_observation and first_observation on listed taxa will get reset 
  # by CheckList.refresh_with_observation
  has_many :listed_taxa, :foreign_key => 'last_observation_id'
  has_many :first_listed_taxa, :class_name => "ListedTaxon", :foreign_key => 'first_observation_id'
  has_many :first_check_listed_taxa, -> { where("listed_taxa.place_id IS NOT NULL") }, :class_name => "ListedTaxon", :foreign_key => 'first_observation_id'
  
  has_many :comments, :as => :parent, :dependent => :destroy
  has_many :identifications, :dependent => :delete_all
  has_many :project_observations, :dependent => :destroy
  has_many :project_invitations, :dependent => :destroy
  has_many :projects, :through => :project_observations
  has_many :quality_metrics, :dependent => :destroy
  has_many :observation_field_values, -> { order("id asc") }, :dependent => :destroy, :inverse_of => :observation
  has_many :observation_fields, :through => :observation_field_values
  has_many :observation_links
  has_and_belongs_to_many :posts
  has_many :observation_sounds, :dependent => :destroy, :inverse_of => :observation
  has_many :sounds, :through => :observation_sounds
  has_many :observations_places, :dependent => :destroy

  FIELDS_TO_SEARCH_ON = %w(names tags description place)
  NON_ELASTIC_ATTRIBUTES = %w(cs establishment_means em h1 m1 week
    csi csa pcid list_id ofv_params)

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
  validates_length_of :observed_on_string, :maximum => 256, :allow_blank => true
  validates_length_of :species_guess, :maximum => 256, :allow_blank => true
  validates_length_of :place_guess, :maximum => 256, :allow_blank => true
  validates_inclusion_of :coordinate_system,
    :in => proc { CONFIG.coordinate_systems.keys.map(&:to_s) },
    :message => "'%{value}' is not a valid coordinate system",
    :allow_blank => true,
    :if => lambda {|o|
      CONFIG.coordinate_systems
    }
  # See /config/locale/en.yml for field labels for `geo_x` and `geo_y`
  validates_numericality_of :geo_x,
    :allow_blank => true,
    :message => "should be a number"
  validates_numericality_of :geo_y,
    :allow_blank => true,
    :message => "should be a number"
  validates_presence_of :geo_x, :if => proc {|o| o.geo_y.present? }
  validates_presence_of :geo_y, :if => proc {|o| o.geo_x.present? }
  
  before_validation :munge_observed_on_with_chronic,
                    :set_time_zone,
                    :set_time_in_time_zone,
                    :set_coordinates

  before_save :strip_species_guess,
              :set_taxon_from_species_guess,
              :set_taxon_from_taxon_name,
              :keep_old_taxon_id,
              :set_latlon_from_place_guess,
              :reset_private_coordinates_if_coordinates_changed,
              :normalize_geoprivacy,
              :set_license,
              :trim_user_agent,
              :update_identifications,
              :set_community_taxon_before_save,
              :set_taxon_from_community_taxon,
              :obscure_coordinates_for_geoprivacy,
              :obscure_coordinates_for_threatened_taxa,
              :set_geom_from_latlon,
              :set_iconic_taxon
  
  before_update :set_quality_grade
                 
  after_save :refresh_lists,
             :refresh_check_lists,
             :update_out_of_range_later,
             :update_default_license,
             :update_all_licenses,
             :update_taxon_counter_caches,
             :update_quality_metrics,
             :update_public_positional_accuracy,
             :update_mappable,
             :set_captive,
             :update_observations_places
  after_create :set_uri,
               :queue_for_sharing
  before_destroy :keep_old_taxon_id
  after_destroy :refresh_lists_after_destroy, :refresh_check_lists, :update_taxon_counter_caches, :create_deleted_observation
  
  ##
  # Named scopes
  # 
  
  # Area scopes
  # scope :in_bounding_box, lambda { |swlat, swlng, nelat, nelng|
  scope :in_bounding_box, lambda {|*args|
    swlat, swlng, nelat, nelng, options = args
    options ||= {}
    if options[:private]
      geom_col = "observations.private_geom"
      lat_col = "observations.private_latitude"
      lon_col = "observations.private_longitude"
    else
      geom_col = "observations.geom"
      lat_col = "observations.latitude"
      lon_col = "observations.longitude"
    end

    # resort to lat/lon cols for date-line spanning boxes
    if swlng.to_f > 0 && nelng.to_f < 0
      where("#{lat_col} > ? AND #{lat_col} < ? AND (#{lon_col} > ? OR #{lon_col} < ?)", 
        swlat.to_f, nelat.to_f, swlng.to_f, nelng.to_f)
    else
      where("ST_Intersects(
        ST_MakeBox2D(ST_Point(#{swlng.to_f}, #{swlat.to_f}), ST_Point(#{nelng.to_f}, #{nelat.to_f})),
        #{geom_col}
      )")
    end
  } do
    def distinct_taxon
      group("taxon_id").where("taxon_id IS NOT NULL").includes(:taxon)
    end
  end
  
  scope :in_place, lambda {|place|
    place_id = if place.is_a?(Place)
      place.id
    elsif place.to_i == 0
      begin
        Place.find(place).try(&:id)
      rescue ActiveRecord::RecordNotFound
        -1
      end
    else
      place.to_i
    end
    joins("JOIN place_geometries ON place_geometries.place_id = #{place_id}").
    where("ST_Intersects(place_geometries.geom, observations.private_geom)")
  }
  
  scope :in_taxons_range, lambda {|taxon|
    taxon_id = taxon.is_a?(Taxon) ? taxon.id : taxon.to_i
    joins("JOIN taxon_ranges ON taxon_ranges.taxon_id = #{taxon_id}").
    where("ST_Intersects(taxon_ranges.geom, observations.private_geom)")
  }
  
  # possibly radius in kilometers
  scope :near_point, Proc.new { |lat, lng, radius|
    lat = lat.to_f
    lng = lng.to_f
    radius = radius.to_f
    radius = 10.0 if radius == 0
    planetary_radius = PLANETARY_RADIUS / 1000 # km
    radius_degrees = radius / (2*Math::PI*planetary_radius) * 360.0
    where("ST_DWithin(ST_Point(?,?), geom, ?)", lng.to_f, lat.to_f, radius_degrees)
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
    iconic_taxon_ids = [iconic_taxon_ids].flatten.map do |itid|
      if itid.is_a?(Taxon)
        itid.id
      elsif itid.to_i == 0
        Taxon::ICONIC_TAXA_BY_NAME[itid].try(:id)
      else
        itid
      end
    end.uniq
    if iconic_taxon_ids.include?(nil)
      where(
        "observations.iconic_taxon_id IS NULL OR observations.iconic_taxon_id IN (?)", 
        iconic_taxon_ids
      )
    elsif !iconic_taxon_ids.empty?
      where("observations.iconic_taxon_id IN (?)", iconic_taxon_ids)
    end
  }
  
  scope :has_geo, -> { where("latitude IS NOT NULL AND longitude IS NOT NULL") }
  scope :has_id_please, -> { where("id_please IS TRUE") }
  scope :has_photos, -> { where("observation_photos_count > 0") }
  scope :has_sounds, -> { where("observation_sounds_count > 0") }
  scope :has_quality_grade, lambda {|quality_grade|
    quality_grade = '' unless QUALITY_GRADES.include?(quality_grade)
    where("quality_grade = ?", quality_grade)
  }
  
  # Find observations by a taxon object.  Querying on taxa columns forces 
  # massive joins, it's a bit sluggish
  scope :of, lambda { |taxon|
    taxon = Taxon.find_by_id(taxon.to_i) unless taxon.is_a? Taxon
    return where("1 = 2") unless taxon
    c = taxon.descendant_conditions.to_sql
    c[0] = "taxa.id = #{taxon.id} OR #{c[0]}"
    joins(:taxon).where(c)
  }
  
  scope :at_or_below_rank, lambda {|rank| 
    rank_level = Taxon::RANK_LEVELS[rank]
    joins(:taxon).where("taxa.rank_level <= ?", rank_level)
  }
  
  # Find observations by user
  scope :by, lambda {|user|
    if user.is_a?(User) || user.to_i > 0
      where("observations.user_id = ?", user)
    else
      joins(:user).where("users.login = ?", user)
    end
  }
  
  # Order observations by date and time observed
  scope :latest, -> { order("observed_on DESC NULLS LAST, time_observed_at DESC NULLS LAST") }
  scope :recently_added, -> { order("observations.id DESC") }
  
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
    when 'project'
      order("project_observations.id #{order} #{extra}").joins(:project_observations)
    else
      order "#{order_by} #{order} #{extra}"
    end
  }
  
  def self.identifications(agreement)
    scope = Observation
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
  scope :week, lambda {|week| where("EXTRACT(WEEK FROM observed_on) = ?", week)}
  
  scope :in_projects, lambda { |projects|
    projects = projects.split(',').map(&:to_i) if projects.is_a?(String)
    projects = [projects].flatten.compact
    projects = projects.map do |p|
      # p.to_i == 0 ? Project.find(p).try(:id) : p rescue nil
      if p.is_a?(Project)
        p.id
      elsif p.to_i == 0
        Project.find(p).try(:id) rescue nil
      else
        p
      end
    end.compact
    # NOTE using :include seems to trigger an erroneous eager load of 
    # observations that screws up sorting kueda 2011-07-22
    joins(:project_observations).where("project_observations.project_id IN (?)", projects)
  }
  
  scope :on, lambda {|date| where(Observation.conditions_for_date(:observed_on, date)) }
  
  scope :created_on, lambda {|date| where(Observation.conditions_for_date("observations.created_at", date))}
  
  scope :out_of_range, -> { where(:out_of_range => true) }
  scope :in_range, -> { where(:out_of_range => false) }
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
    scope = joins(:photos)
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

  scope :between_hours, lambda{|h1, h2|
    h1 = h1.to_i % 24
    h2 = h2.to_i % 24
    where("EXTRACT(hour FROM ((time_observed_at AT TIME ZONE 'GMT') AT TIME ZONE zic_time_zone)) BETWEEN ? AND ?", h1, h2)
  }

  scope :between_months, lambda{|m1, m2|
    m1 = m1.to_i % 12
    m2 = m2.to_i % 12
    if m1 > m2
      where("EXTRACT(month FROM observed_on) >= ? OR EXTRACT(month FROM observed_on) <= ?", m1, m2)
    else
      where("EXTRACT(month FROM observed_on) BETWEEN ? AND ?", m1, m2)
    end
  }

  scope :between_dates, lambda{|d1, d2|
    t1 = (Time.parse(URI.unescape(d1)) rescue Time.now)
    t2 = (Time.parse(URI.unescape(d2)) rescue Time.now)
    if d1.to_s.index(':')
      where("time_observed_at BETWEEN ? AND ? OR (time_observed_at IS NULL AND observed_on BETWEEN ? AND ?)", t1, t2, t1.to_date, t2.to_date)
    else
      where("observed_on BETWEEN ? AND ?", t1, t2)
    end
  }

  scope :dbsearch, lambda {|*args|
    q, on = args
    case on
    when 'species_guess'
      where("observations.species_guess ILIKE", "%#{q}%")
    when 'description'
      where("observations.description ILIKE", "%#{q}%")
    when 'place_guess'
      where("observations.place_guess ILIKE", "%#{q}%")
    when 'tags'
      where("observations.cached_tag_list ILIKE", "%#{q}%")
    else
      where("observations.species_guess ILIKE ? OR observations.description ILIKE ? OR observations.cached_tag_list ILIKE ? OR observations.place_guess ILIKE ?", 
        "%#{q}%", "%#{q}%", "%#{q}%", "%#{q}%")
    end
  }
  
  def self.near_place(place)
    place = (Place.find(place) rescue nil) unless place.is_a?(Place)
    if place.swlat
      Observation.in_bounding_box(place.swlat, place.swlng, place.nelat, place.nelng)
    else
      Observation.near_point(place.latitude, place.longitude)
    end
  end

  def self.site_search_params(site, params = {})
    search_params = params.dup
    return search_params unless site && site.is_a?(Site)
    if CONFIG.site_only_observations && search_params[:site].blank?
      search_params[:site] ||= FakeView.root_url
    end
    if !search_params[:swlat] &&
      !search_params[:place_id] && search_params[:bbox].blank?
      if site.place
        search_params[:place] = site.place
      elsif CONFIG.bounds
        search_params[:nelat] ||= CONFIG.bounds["nelat"]
        search_params[:nelng] ||= CONFIG.bounds["nelng"]
        search_params[:swlat] ||= CONFIG.bounds["swlat"]
        search_params[:swlng] ||= CONFIG.bounds["swlng"]
      end
    end
    search_params
  end

  def self.elastic_query(params, options = {})
    elastic_params = params_to_elastic_query(params, options)
    if elastic_params.nil?
      # a dummy WillPaginate Collection is the most compatible empty result
      return WillPaginate::Collection.new(1, 30, 0)
    end
    observations = Observation.elastic_paginate(elastic_params)
    # preload the most commonly needed associations,
    # and union it with any extra_preloads
    Observation.preload_associations(observations, [
      { user: :stored_preferences },
      { taxon: { taxon_names: :place_taxon_names } },
      { iconic_taxon: :taxon_descriptions },
      { photos: [ :user, :flags ] },
      :stored_preferences, :flags, :quality_metrics ] |
      elastic_params[:extra_preloads])
    observations
  end

  def self.query_params(params)
    p = params.clone.symbolize_keys
    if p[:swlat].blank? && p[:swlng].blank? && p[:nelat].blank? && p[:nelng].blank? && p[:BBOX]
      p[:swlng], p[:swlat], p[:nelng], p[:nelat] = p[:BBOX].split(',')
    end
    unless p[:place_id].blank?
      p[:place] = begin
        Place.find(p[:place_id])
      rescue ActiveRecord::RecordNotFound
        nil
      end
    end
    p[:q] = sanitize_query(p[:q]) unless p[:q].blank?
    p[:search_on] = nil unless Observation::FIELDS_TO_SEARCH_ON.include?(p[:search_on])
    # iconic_taxa
    if p[:iconic_taxa]
      # split a string of names
      if p[:iconic_taxa].is_a? String
        p[:iconic_taxa] = p[:iconic_taxa].split(',')
      end
      
      # resolve taxa entered by name
      allows_unknown = p[:iconic_taxa].include?(nil)
      p[:iconic_taxa] = p[:iconic_taxa].compact.map do |it|
        it = it.last if it.is_a?(Array)
        if it.is_a? Taxon
          it
        elsif it.to_i == 0
          allows_unknown = true if it.to_s.downcase == "unknown"
          Taxon::ICONIC_TAXA_BY_NAME[it]
        else
          Taxon::ICONIC_TAXA_BY_ID[it]
        end
      end.uniq.compact
      p[:iconic_taxa] << nil if allows_unknown
    end
    if !p[:taxon_id].blank?
      p[:observations_taxon] = Taxon.find_by_id(p[:taxon_id].to_i)
    elsif !p[:taxon_name].blank?
      begin
        p[:observations_taxon] = Taxon.single_taxon_for_name(p[:taxon_name], iconic_taxa: p[:iconic_taxa])
      rescue ActiveRecord::StatementInvalid => e
        raise e unless e.message =~ /invalid byte sequence/
        taxon_name_conditions[1] = p[:taxon_name].encode('UTF-8')
        p[:observations_taxon] = TaxonName.where(taxon_name_conditions).joins(includes).first.try(:taxon)
      end
    end
    if !p[:observations_taxon] && !p[:taxon_ids].blank?
      p[:observations_taxon_ids] = p[:taxon_ids]
      p[:observations_taxa] = Taxon.where(id: p[:observations_taxon_ids]).limit(100)
    end

    if p[:has]
      p[:has] = p[:has].split(',') if p[:has].is_a?(String)
      p[:id_please] = true if p[:has].include?('id_please')
      p[:with_photos] = true if p[:has].include?('photos')
      p[:with_sounds] = true if p[:has].include?('sounds')
      p[:with_geo] = true if p[:has].include?('geo')
    end

    p[:captive] = p[:captive].yesish? unless p[:captive].blank?

    if p[:skip_order]
      p.delete(:order)
      p.delete(:order_by)
    else
      p[:order_by] = "created_at" if p[:order_by] == "observations.id"
      if ObservationsController::ORDER_BY_FIELDS.include?(p[:order_by].to_s)
        p[:order] = if %w(asc desc).include?(p[:order].to_s.downcase)
          p[:order]
        else
          'desc'
        end
      else
        p[:order_by] = "observations.id"
        p[:order] = "desc"
      end
    end

    # date
    date_pieces = [p[:year], p[:month], p[:day]]
    unless date_pieces.map{|d| d.blank? ? nil : d}.compact.blank?
      p[:on] = date_pieces.join('-')
    end
    if p[:on].to_s =~ /^\d{4}/
      p[:observed_on] = p[:on]
      if d = Observation.split_date(p[:observed_on])
        p[:observed_on_year], p[:observed_on_month], p[:observed_on_day] = [ d[:year], d[:month], d[:day] ]
      end
    end
    p[:observed_on_year] ||= p[:year].to_i unless p[:year].blank?
    p[:observed_on_month] ||= p[:month].to_i unless p[:month].blank?
    p[:observed_on_day] ||= p[:day].to_i unless p[:day].blank?

    # observation fields
    ofv_params = p.select{|k,v| k =~ /^field\:/}
    unless ofv_params.blank?
      p[:ofv_params] = {}
      ofv_params.each do |k,v|
        p[:ofv_params][k] = {
          :normalized_name => ObservationField.normalize_name(k.to_s),
          :value => v
        }
      end
      observation_fields = ObservationField.where("lower(name) IN (?)", p[:ofv_params].map{|k,v| v[:normalized_name]})
      p[:ofv_params].each do |k,v|
        v[:observation_field] = observation_fields.detect do |of|
          v[:normalized_name] == ObservationField.normalize_name(of.name)
        end
      end
      p[:ofv_params].delete_if{|k,v| v[:observation_field].blank?}
    end

    unless p[:user_id].blank?
      p[:user] = User.find_by_id(p[:user_id])
      p[:user] ||= User.find_by_login(p[:user_id])
    end
    if p[:user].blank? && !p[:login].blank?
      p[:user] ||= User.find_by_login(p[:login])
    end

    unless p[:projects].blank?
      project_ids = [p[:projects]].flatten
      p[:projects] = Project.find(project_ids) rescue []
      p[:projects] = p[:projects].compact
      if p[:projects].blank?
        project_ids.each do |project_id|
          p[:projects] << Project.find(project_id) rescue nil
        end
        p[:projects] = p[:projects].compact
      end
    end

    if p[:pcid] && p[:pcid] != 'any'
      p[:pcid] = p[:pcid].yesish?
    end

    unless p[:not_in_project].blank?
      p[:not_in_project] = Project.find(p[:not_in_project]) rescue nil
    end

    p[:rank] = p[:rank] if Taxon::VISIBLE_RANKS.include?(p[:rank])
    p[:hrank] = p[:hrank] if Taxon::VISIBLE_RANKS.include?(p[:hrank])
    p[:lrank] = p[:lrank] if Taxon::VISIBLE_RANKS.include?(p[:lrank])

    p.each do |k,v|
      p[k] = nil if v.is_a?(String) && v.blank?
    end

    p[:_query_params_set] = true
    p
  end
  
  #
  # Uses scopes to perform a conditional search.
  # May be worth looking into squirrel or some other rails friendly search add on
  #
  def self.query(params = {})
    scope = self

    place_id = if params[:place_id].to_i > 0
      params[:place_id]
    elsif !params[:place_id].blank?
      Place.find(params[:place_id]).try(:id) rescue 0
    end
    
    # support bounding box queries
    if (!params[:swlat].blank? && !params[:swlng].blank? && 
         !params[:nelat].blank? && !params[:nelng].blank?)
      viewer = params[:viewer].is_a?(User) ? params[:viewer].id : params[:viewer]
      scope = scope.in_bounding_box(params[:swlat], params[:swlng], params[:nelat], params[:nelng], :private => (viewer && viewer == params[:user_id]))
    elsif !params[:BBOX].blank?
      swlng, swlat, nelng, nelat = params[:BBOX].split(',')
      scope = scope.in_bounding_box(swlat, swlng, nelat, nelng)
    elsif params[:lat] && params[:lng]
      scope = scope.near_point(params[:lat], params[:lng], params[:radius])
    end
    
    # has (boolean) selectors
    if params[:has]
      params[:has] = params[:has].split(',') if params[:has].is_a? String
      params[:has].select{|s| %w(geo id_please photos sounds).include?(s)}.each do |prop|
        scope = case prop
          when 'geo' then scope.has_geo
          when 'id_please' then scope.has_id_please
          when 'photos' then scope.has_photos
          when 'sounds' then scope.has_sounds
        end
      end
    end
    scope = scope.identifications(params[:identifications]) if params[:identifications]
    scope = scope.has_iconic_taxa(params[:iconic_taxa]) if params[:iconic_taxa]
    scope = scope.order_by("#{params[:order_by]} #{params[:order]}") if params[:order_by]
    
    scope = scope.has_quality_grade( params[:quality_grade]) if QUALITY_GRADES.include?(params[:quality_grade])
    
    if taxon = params[:taxon]
      scope = scope.of(taxon.is_a?(Taxon) ? taxon : taxon.to_i)
    elsif !params[:taxon_id].blank?
      scope = scope.of(params[:taxon_id].to_i)
    elsif !params[:taxon_name].blank?
      scope = scope.of(Taxon.single_taxon_for_name(params[:taxon_name], :iconic_taxa => params[:iconic_taxa]))
    elsif !params[:taxon_ids].blank?
      taxon_ids = params[:taxon_ids].map(&:to_i)
      if params[:taxon_ids].size == 1
        scope = scope.of(taxon_ids.first)
      else
        taxa = Taxon::ICONIC_TAXA.select{|t| taxon_ids.include?(t.id)}
        if taxa.size == taxon_ids.size
          scope = scope.has_iconic_taxa(taxon_ids)
        end
      end
    end
    if params[:on]
      scope = scope.on(params[:on])
    elsif params[:year] || params[:month] || params[:day]
      date_pieces = [params[:year], params[:month], params[:day]]
      unless date_pieces.map{|d| d.blank? ? nil : d}.compact.blank?
        scope = scope.on(date_pieces.join('-'))
      end
    end
    scope = scope.by(params[:user_id]) if params[:user_id]
    scope = scope.in_projects(params[:projects]) if params[:projects]
    scope = scope.in_place(place_id) unless params[:place_id].blank?
    scope = scope.created_on(params[:created_on]) if params[:created_on]
    scope = scope.out_of_range if params[:out_of_range] == 'true'
    scope = scope.in_range if params[:out_of_range] == 'false'
    scope = scope.license(params[:license]) unless params[:license].blank?
    scope = scope.photo_license(params[:photo_license]) unless params[:photo_license].blank?
    scope = scope.where(:captive => true) if params[:captive].yesish?
    if params[:mappable].yesish?
      scope = scope.where(:mappable => true)
    elsif params[:mappable] && params[:mappable].noish?
      scope = scope.where(:mappable => false)
    end
    scope = scope.where("observations.captive = ? OR observations.captive IS NULL", false) if [false, 'false', 'f', 'no', 'n', 0, '0'].include?(params[:captive])
    unless params[:ofv_params].blank?
      params[:ofv_params].each do |k,v|
        scope = scope.has_observation_field(v[:observation_field], v[:value])
      end
    end

    # TODO change this to use the Site model
    if !params[:site].blank? && params[:site] != 'any'
      uri = params[:site]
      uri = "http://#{uri}" unless uri =~ /^http\:\/\//
      scope = scope.where("observations.uri LIKE ?", "#{uri}%")
    end

    if !params[:site_id].blank? && site = Site.find_by_id(params[:site_id])
      scope = scope.where("observations.site_id = ?", site)
    end

    if !params[:h1].blank? && !params[:h2].blank?
      scope = scope.between_hours(params[:h1], params[:h2])
    end

    if !params[:m1].blank? && !params[:m2].blank?
      scope = scope.between_months(params[:m1], params[:m2])
    end

    if !params[:d1].blank? && !params[:d2].blank?
      scope = scope.between_dates(params[:d1], params[:d2])
    end

    unless params[:week].blank?
      scope = scope.week(params[:week])
    end

    if !params[:cs].blank?
      scope = scope.joins(:taxon => :conservation_statuses).where("conservation_statuses.status IN (?)", [params[:cs]].flatten)
      scope = if place_id.blank?
        scope.where("conservation_statuses.place_id IS NULL")
      else
        scope.where("conservation_statuses.place_id = ? OR conservation_statuses.place_id IS NULL", place_id)
      end
    end

    if !params[:csi].blank?
      iucn_equivs = [params[:csi]].flatten.map{|v| Taxon::IUCN_CODE_VALUES[v.upcase]}.compact.uniq
      scope = scope.joins(:taxon => :conservation_statuses).where("conservation_statuses.iucn IN (?)", iucn_equivs)
      scope = if place_id.blank?
        scope.where("conservation_statuses.place_id IS NULL")
      else
        scope.where("conservation_statuses.place_id = ? OR conservation_statuses.place_id IS NULL", place_id)
      end
    end

    if !params[:csa].blank?
      scope = scope.joins(:taxon => :conservation_statuses).where("conservation_statuses.authority = ?", params[:csa])
      scope = if place_id.blank?
        scope.where("conservation_statuses.place_id IS NULL")
      else
        scope.where("conservation_statuses.place_id = ? OR conservation_statuses.place_id IS NULL", place_id)
      end
    end

    establishment_means = params[:establishment_means] || params[:em]
    if !place_id.blank? && !establishment_means.blank?
      scope = scope.
        joins("JOIN listed_taxa ON listed_taxa.taxon_id = observations.taxon_id").
        where("listed_taxa.place_id = ?", place_id)
      scope = case establishment_means
      when ListedTaxon::NATIVE
        scope.where("listed_taxa.establishment_means IN (?)", ListedTaxon::NATIVE_EQUIVALENTS)
      when ListedTaxon::INTRODUCED
        scope.where("listed_taxa.establishment_means IN (?)", ListedTaxon::INTRODUCED_EQUIVALENTS)
      else
        scope.where("listed_taxa.establishment_means = ?", establishment_means)
      end
    end

    if params[:pcid] && params[:pcid] != "any"
      scope = if [true, 'true', 't', 1, '1', 'y', 'yes'].include?(params[:pcid])
        scope.joins(:project_observations).where("project_observations.curator_identification_id IS NOT NULL")
      else
        scope.joins(:project_observations).where("project_observations.curator_identification_id IS NULL")
      end
    end

    unless params[:geoprivacy].blank?
      scope = case params[:geoprivacy]
      when "any"
        # do nothing
      when OPEN
        scope.where("geoprivacy IS NULL")
      when "obscured_private"
        scope.where("geoprivacy IN (?)", GEOPRIVACIES)
      else
        scope.where(:geoprivacy => params[:geoprivacy])
      end
    end

    rank = params[:rank].to_s.downcase
    if Taxon::VISIBLE_RANKS.include?(rank)
      scope = scope.joins(:taxon).where("taxa.rank = ?", rank)
    end

    high_rank = params[:hrank]
    if Taxon::VISIBLE_RANKS.include?(high_rank)
      rank_level = Taxon::RANK_LEVELS[high_rank]
      scope = scope.joins(:taxon).where("taxa.rank_level <= ?", rank_level)
    end

    low_rank = params[:lrank]
    if Taxon::VISIBLE_RANKS.include?(low_rank)
      rank_level = Taxon::RANK_LEVELS[low_rank]
      scope = scope.joins(:taxon).where("taxa.rank_level >= ?", rank_level)
    end

    unless params[:updated_since].blank?
      if timestamp = Chronic.parse(params[:updated_since])
        scope = scope.where("observations.updated_at > ?", timestamp)
      else
        scope = scope.where("1 = 2")
      end
    end

    unless params[:q].blank?
      scope = scope.dbsearch(params[:q])
    end

    if list = List.find_by_id(params[:list_id])
      if list.listed_taxa.count <= 2000
        scope = scope.joins("JOIN listed_taxa ON listed_taxa.list_id = #{list.id}").where("listed_taxa.taxon_id = observations.taxon_id", list)
      end
    end

    if params[:identified].yesish?
      scope = scope.has_taxon
    elsif params[:identified].noish?
      scope = scope.where("taxon_id IS NULL")
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
    s = self.species_guess.blank? ? I18n.t(:something) : self.species_guess
    if options[:verb]
      s += options[:verb] == true ? I18n.t(:observed).downcase : " #{options[:verb]}"
    end
    unless self.place_guess.blank? || options[:no_place_guess] || coordinates_obscured?
      s += " #{I18n.t(:from, :default => 'from').downcase} #{self.place_guess}"
    end
    s += " #{I18n.t(:on_day)}  #{I18n.l(self.observed_on, :format => :long)}" unless self.observed_on.blank?
    unless self.time_observed_at.blank? || options[:no_time]
      s += " #{I18n.t(:at)} #{self.time_observed_at_in_zone.to_s(:plain_time)}"
    end
    s += " #{I18n.t(:by).downcase} #{self.user.try(:login)}" unless options[:no_user]
    s.gsub(/\s+/, ' ')
  end

  # returns a string for sharing on social media (fb, twitter)
  def to_share_s
    return self.to_plain_s({:no_user=>true})
  end
  
  def time_observed_at_utc
    time_observed_at.try(:utc)
  end
  
  def serializable_hash(options = {})
    # making a deep copy of the options so they don't get modified
    # This was more effective than options.deep_dup
    if options[:include] && (options[:include].is_a?(Hash) || options[:include].is_a?(Array))
      options[:include] = options[:include].marshal_copy
    end
    # don't use delete here, it will just remove the option for all 
    # subsequent records in an array
    options[:include] = if options[:include].is_a?(Hash)
      options[:include].map{|k,v| {k => v}}
    else
      [options[:include]].flatten.compact
    end
    options[:methods] ||= []
    options[:methods] += [:created_at_utc, :updated_at_utc, :time_observed_at_utc]
    viewer = options[:viewer]
    viewer_id = viewer.is_a?(User) ? viewer.id : viewer.to_i
    options[:except] ||= []
    options[:except] += [:user_agent]
    if viewer_id != user_id && !options[:force_coordinate_visibility]
      options[:except] += [:private_latitude, :private_longitude, :private_positional_accuracy, :geom, :private_geom]
      options[:except] += [:place_guess] if coordinates_obscured?
      options[:methods] << :coordinates_obscured
    end
    options[:except] += [:cached_tag_list, :geom, :private_geom]
    options[:except].uniq!
    options[:methods].uniq!
    h = super(options)
    h.each do |k,v|
      h[k] = v.gsub(/<script.*script>/i, "") if v.is_a?(String)
    end
    h
  end
  
  #
  # Return a time from observed_on and time_observed_at
  #
  def datetime
    if observed_on && errors[:observed_on].blank?
      if time_observed_at
        time_observed_at.to_time
      else
        # use UTC to create the time
        Time.utc(observed_on.year,
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
    tz_js_offset_pattern = /(GMT)?([+-]\d{4})/ # contains GMT-0800
    tz_colon_offset_pattern = /(GMT|HSP)([+-]\d+:\d+)/ # contains (GMT-08:00)
    tz_failed_abbrev_pattern = /\(#{tz_colon_offset_pattern}\)/
    
    if date_string =~ /#{tz_js_offset_pattern} #{tz_failed_abbrev_pattern}/
      date_string = date_string.sub(tz_failed_abbrev_pattern, '').strip
    end

    # Rails timezone support doesn't seem to recognize this abbreviation, and
    # frankly I have no idea where ActiveSupport::TimeZone::CODES comes from.
    # In case that ever stops working or a less hackish solution is required,
    # check out https://gist.github.com/kueda/3e6f77f64f792b4f119f
    tz_abbrev = date_string[tz_abbrev_pattern, 1]
    tz_abbrev = 'CET' if tz_abbrev == 'CEST'
    
    if parsed_time_zone = ActiveSupport::TimeZone::CODES[tz_abbrev]
      date_string = observed_on_string.sub(tz_abbrev_pattern, '')
      date_string = date_string.sub(tz_js_offset_pattern, '').strip
      self.time_zone = parsed_time_zone.name if observed_on_string_changed?
    elsif (offset = date_string[tz_offset_pattern, 1]) && 
        (n = offset.to_f / 100) && 
        (key = n == 0 ? 0 : n.floor + (n%n.floor)/0.6) && 
        (parsed_time_zone = ActiveSupport::TimeZone[key])
      date_string = date_string.sub(tz_offset_pattern, '')
      self.time_zone = parsed_time_zone.name if observed_on_string_changed?
    elsif (offset = date_string[tz_js_offset_pattern, 2]) && 
        (n = offset.to_f / 100) && 
        (key = n == 0 ? 0 : n.floor + (n%n.floor)/0.6) && 
        (parsed_time_zone = ActiveSupport::TimeZone[key])
      date_string = date_string.sub(tz_js_offset_pattern, '')
      date_string = date_string.sub(/^(Sun|Mon|Tue|Wed|Thu|Fri|Sat)\s+/i, '')
      self.time_zone = parsed_time_zone.name if observed_on_string_changed?
    elsif (offset = date_string[tz_colon_offset_pattern, 2]) && 
        (t = Time.parse(offset)) && 
        (parsed_time_zone = ActiveSupport::TimeZone[t.hour+t.min/60.0])
      date_string = date_string.sub(/#{tz_colon_offset_pattern}|#{tz_failed_abbrev_pattern}/, '')
      self.time_zone = parsed_time_zone.name if observed_on_string_changed?
    end
    
    date_string.sub!('T', ' ') if date_string =~ /\d{4}-\d{2}-\d{2}T/
    date_string.sub!(/(\d{2}:\d{2}:\d{2})\.\d+/, '\\1')
    
    # strip leading month if present
    date_string.sub!(/^[A-z]{3} ([A-z]{3})/, '\\1')

    # strip paranthesized stuff
    date_string.gsub!(/\(.*\)/, '')
    
    # Set the time zone appropriately
    old_time_zone = Time.zone
    begin
      Time.zone = time_zone || user.try(:time_zone)
    rescue ArgumentError
      # Usually this would happen b/c of an invalid time zone being specified
      self.time_zone = time_zone_was || old_time_zone.name
    end
    Chronic.time_class = Time.zone
    
    begin
      # Start parsing...
      t = begin
        Chronic.parse(date_string)
      rescue ArgumentError
        nil
      end
      t = Chronic.parse(date_string.split[0..-2].join(' ')) unless t 
      if !t && (locale = user.locale || I18n.locale)
        date_string = englishize_month_abbrevs_for_locale(date_string, locale)
        t = Chronic.parse(date_string)
      end

      if !t
        I18N_SUPPORTED_LOCALES.each do |locale|
          date_string = englishize_month_abbrevs_for_locale(date_string, locale)
          break if t = Chronic.parse(date_string) 
        end
      end
      return true unless t
    
      # Re-interpret future dates as being in the past
      t = Chronic.parse(date_string, :context => :past) if t > Time.now
      
      self.observed_on = t.to_date if t
    
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
    rescue RuntimeError, ArgumentError
      # ignore these, just don't set the date
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

  def englishize_month_abbrevs_for_locale(date_string, locale)
    # HACK attempt to translate month abbreviations into English. 
    # A much better approach would be add Spanish and any other supported
    # locales to https://github.com/olojac/chronic-l10n and switch to the
    # 'localized' branch of Chronic, which seems to clear our test suite.
    return date_string if locale.to_s =~ /^en/
    return date_string unless I18N_SUPPORTED_LOCALES.include?(locale)
    I18n.t('date.abbr_month_names', :locale => :en).each_with_index do |en_month_name,i|
      next if i == 0
      localized_month_name = I18n.t('date.abbr_month_names', :locale => locale)[i]
      next if localized_month_name == en_month_name
      date_string.gsub!(/#{localized_month_name}([\s\,])/, "#{en_month_name}\\1")
    end
    date_string
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
      attrs = {:user => user, :taxon => taxon, :observation => self, :skip_observation => true}
      owners_ident = if new_record?
        self.identifications.build(attrs)
      else
        self.identifications.create(attrs)
      end
    elsif taxon.blank? && owners_ident && owners_ident.current?
      if identifications.where(:user_id => user_id).count > 1
        owners_ident.update_attributes(:current => false, :skip_observation => true)
      else
        owners_ident.skip_observation = true
        owners_ident.destroy
      end
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
        existing = observation_field_values.where(:observation_field_id => v["observation_field_id"]).first unless v["observation_field_id"].blank?
        existing ||= observation_field_values.joins(:observation_fields).where("lower(observation_fields.name) = ?", v["name"]).first unless v["name"].blank?
        attr_array[i]["id"] = existing.id if existing
      elsif !ObservationFieldValue.where("id = ?", v["id"]).exists?
        attr_array[i].delete("id")
      end
    end
    assign_nested_attributes_for_collection_association(:observation_field_values, attr_array)
  end
  
  #
  # Update the user's lists with changes to this observation's taxon
  #
  # If the observation is the last_observation in any of the user's lists,
  # then the last_observation should be reset to another observation.
  #
  def refresh_lists
    return true if skip_refresh_lists
    return true unless taxon_id_changed? || quality_grade_changed?
    
    # Update the observation's current taxon and/or a previous one that was
    # just removed/changed
    target_taxa = [
      taxon, 
      Taxon.find_by_id(@old_observation_taxon_id)
    ].compact.uniq
    
    # Don't refresh all the lists if nothing changed
    return true if target_taxa.empty?
    
    # Refreh the ProjectLists
    ProjectList.delay(priority: USER_INTEGRITY_PRIORITY, queue: "slow",
      unique_hash: { "ProjectList::refresh_with_observation": id }).
      refresh_with_observation(id, :taxon_id => taxon_id,
        :taxon_id_was => taxon_id_was, :user_id => user_id, :created_at => created_at)

    # Don't refresh LifeLists and Lists if only quality grade has changed
    return true unless taxon_id_changed?
    List.delay(priority: USER_INTEGRITY_PRIORITY, queue: "slow",
      unique_hash: { "List::refresh_with_observation": id }).
      refresh_with_observation(id, :taxon_id => taxon_id,
        :taxon_id_was => taxon_id_was, :user_id => user_id, :created_at => created_at,
        :skip_subclasses => true)
    LifeList.delay(priority: USER_INTEGRITY_PRIORITY, queue: "slow",
      unique_hash: { "LifeList::refresh_with_observation": id }).
      refresh_with_observation(id, :taxon_id => taxon_id,
        :taxon_id_was => taxon_id_was, :user_id => user_id, :created_at => created_at)

    # Reset the instance var so it doesn't linger around
    @old_observation_taxon_id = nil
    true
  end
  
  def refresh_check_lists
    return true if skip_refresh_check_lists
    refresh_needed = (georeferenced? || was_georeferenced?) && 
      (taxon_id || taxon_id_was) && 
      (quality_grade_changed? || taxon_id_changed? || latitude_changed? || longitude_changed? || observed_on_changed?)
    return true unless refresh_needed
    CheckList.delay(priority: INTEGRITY_PRIORITY, queue: "slow",
      unique_hash: { "CheckList::refresh_with_observation": id }).
      refresh_with_observation(id, :taxon_id => taxon_id,
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
    return true if skip_refresh_lists
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
  # Set the iconic taxon if it hasn't been set
  #
  def set_iconic_taxon
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
    self.species_guess.to_s.strip! unless species_guess.blank?
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
    self.zic_time_zone = ActiveSupport::TimeZone::MAPPING[time_zone] unless time_zone.blank?
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
  
  def set_captive
    update_column(:captive, captive_cultivated)
  end
  
  def lsid
    "lsid:#{URI.parse(CONFIG.site_url).host}:observations:#{id}"
  end
  
  def component_cache_key(options = {})
    Observation.component_cache_key(id, options)
  end
  
  def self.component_cache_key(id, options = {})
    key = "obs_comp_#{id}"
    key += "_"+options.sort.map{|k,v| "#{k}-#{v}"}.join('_') unless options.blank?
    key
  end
  
  def num_identifications_by_others
    num_identification_agreements + num_identification_disagreements
  end
  
  def appropriate?
    return false if flags.detect{ |f| f.resolved == false }
    return false if observation_photos_count > 0 && photos.detect{ |p| p.flags.detect{ |f| f.resolved == false } }
    true
  end
  
  def georeferenced?
    (!latitude.nil? && !longitude.nil?) || (!private_latitude.nil? && !private_longitude.nil?)
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
    if community_taxon_rejected?
      num_identification_agreements.to_i > 0 && num_identification_agreements > num_identification_disagreements
    else
      !community_taxon_id.blank? && taxon_id == community_taxon_id
    end
  end
  
  def quality_metrics_pass?
    QualityMetric::METRICS.each do |metric|
      return false unless passes_quality_metric?(metric)
    end
    true
  end

  def passes_quality_metric?(metric)
    score = quality_metric_score(metric)
    score.blank? || score >= 0.5
  end
  
  def research_grade?
    return false unless georeferenced?
    return false unless community_supported_id?
    return false unless quality_metrics_pass?
    return false unless observed_on?
    return false unless (photos? || sounds?)
    return false unless appropriate?
    if root = (Taxon::LIFE || Taxon.roots.select("id, name, rank").find_by_name('Life'))
      return false if community_taxon_id == root.id
    end
    true
  end
  
  def photos?
    observation_photos.loaded? ? ! observation_photos.empty? : observation_photos.exists?
  end

  def sounds?
    sounds.exists?
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
    if observation.quality_grade_changed?
      CheckList.delay(priority: INTEGRITY_PRIORITY, queue: "slow",
        unique_hash: { "CheckList::refresh_with_observation": id }).
        refresh_with_observation(observation.id, :taxon_id => observation.taxon_id)
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

  def coordinates_private?
    latitude.blank? && longitude.blank? && private_latitude? && private_longitude?
  end

  def coordinates_changed?
    latitude_changed? || longitude_changed? || private_latitude_changed? || private_longitude_changed?
  end
  
  def geoprivacy_private?
    geoprivacy == PRIVATE
  end
  
  def geoprivacy_obscured?
    geoprivacy == OBSCURED
  end
  
  def coordinates_viewable_by?(viewer)
    return true unless coordinates_obscured?
    viewer = User.find_by_id(viewer) unless viewer.is_a?(User)
    return false unless viewer
    return true if user_id == viewer.id
    project_ids = if projects.loaded?
      projects.map(&:id)
    else
      project_observations.map(&:project_id)
    end
    viewer.project_users.select{|pu| project_ids.include?(pu.project_id) && ProjectUser::ROLES.include?(pu.role)}.each do |pu|
      if project_observations.detect{|po| po.project_id == pu.project_id && po.prefers_curator_coordinate_access?}
        return true
      end
    end
    false
  end
  
  def reset_private_coordinates_if_coordinates_changed
    if (latitude_changed? || longitude_changed?)
      self.private_latitude = nil
      self.private_longitude = nil
    end
    true
  end

  def normalize_geoprivacy
    self.geoprivacy = nil unless GEOPRIVACIES.include?(geoprivacy)
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
    lat = private_latitude.blank? ? latitude : private_latitude
    lon = private_longitude.blank? ? longitude : private_longitude
    t = taxon || community_taxon
    taxon_geoprivacy = t ? t.geoprivacy(:latitude => lat, :longitude => lon) : nil
    case taxon_geoprivacy
    when OBSCURED
      obscure_coordinates(M_TO_OBSCURE_THREATENED_TAXA) unless coordinates_obscured?
    when PRIVATE
      unless coordinates_private?
        obscure_coordinates(M_TO_OBSCURE_THREATENED_TAXA)
        self.latitude, self.longitude = [nil, nil]
      end
    else
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
    set_geom_from_latlon
  end
  
  def lat_lon_in_place_guess?
    !place_guess.blank? && place_guess !~ /[a-cf-mo-rt-vx-z]/i && !place_guess.scan(COORDINATE_REGEX).blank?
  end
  
  def obscured_place_guess
    return place_guess if place_guess.blank?
    return nil if lat_lon_in_place_guess?
    place_guess.sub(/^\d[\d\-A-z]+\s+/, '')
  end
  
  def unobscure_coordinates
    return unless coordinates_obscured? || coordinates_private?
    return unless geoprivacy.blank?
    self.latitude = private_latitude
    self.longitude = private_longitude
    self.private_latitude = nil
    self.private_longitude = nil
    set_geom_from_latlon
  end
  
  def iconic_taxon_name
    return nil if iconic_taxon_id.blank?
    if Taxon::ICONIC_TAXA_BY_ID.blank?
      association(:iconic_taxon).loaded? ? iconic_taxon.try(:name) : Taxon.select("id, name").where(:id => iconic_taxon_id).first.try(:name)
    else
      Taxon::ICONIC_TAXA_BY_ID[iconic_taxon_id].try(:name)
    end
  end

  def captive_cultivated
    !passes_quality_metric?(QualityMetric::WILD)
  end

  ##### Community Taxon #########################################################

  def get_community_taxon(options = {})
    return unless identifications.current.count > 1
    node = community_taxon_nodes(options).select{|n| n[:cumulative_count] > 1}.sort_by do |n| 
      [
        n[:score].to_f > COMMUNITY_TAXON_SCORE_CUTOFF ? 1 : 0, # only consider taxa with a score above the cutoff
        0 - (n[:taxon].rank_level || 500) # within that set, sort by rank level, i.e. choose lowest rank
      ]
    end.last
    
    # # Visualizing this stuff is pretty useful for testing, so please leave this in
    # puts
    # width = 15
    # %w(taxon_id taxon_name cc dc cdc score).each do |c|
    #   print c.ljust(width)
    # end
    # puts
    # community_taxon_nodes.sort_by{|n| n[:taxon].ancestry || ""}.each do |n|
    #   print n[:taxon].id.to_s.ljust(width)
    #   print n[:taxon].name.to_s.ljust(width)
    #   print n[:cumulative_count].to_s.ljust(width)
    #   print n[:disagreement_count].to_s.ljust(width)
    #   print n[:conservative_disagreement_count].to_s.ljust(width)
    #   print n[:score].to_s.ljust(width)
    #   puts
    # end

    return unless node
    node[:taxon]
  end

  def community_taxon_nodes(options = {})
    return @community_taxon_nodes if @community_taxon_nodes && !options[:force]
    # work on current identifications
    working_idents = identifications.current.includes(:taxon).sort_by(&:id)

    # load all ancestor taxa implied by identifications
    ancestor_ids = working_idents.map{|i| i.taxon.ancestor_ids}.flatten.uniq.compact
    taxon_ids = working_idents.map{|i| [i.taxon_id] + i.taxon.ancestor_ids}.flatten.uniq.compact
    taxa = Taxon.where("id IN (?)", taxon_ids)
    taxon_ids_count = taxon_ids.size

    @community_taxon_nodes = taxa.map do |id_taxon|
      # count all identifications of this taxon and its descendants
      cumulative_count = working_idents.select{|i| i.taxon.self_and_ancestor_ids.include?(id_taxon.id)}.size

      # count identifications of taxa that are outside of this taxon's subtree
      # (i.e. absolute disagreements)
      disagreement_count = working_idents.reject{|i|
       id_taxon.self_and_ancestor_ids.include?(i.taxon_id) || i.taxon.self_and_ancestor_ids.include?(id_taxon.id)
      }.size

      # count identifications of taxa that are ancestors of this taxon but
      # were made after the first identification of this taxon (i.e.
      # conservative disagreements). Note that for genus1 > species1, an
      # identification of species1 implies an identification of genus1
      first_ident = working_idents.detect{|i| i.taxon.self_and_ancestor_ids.include?(id_taxon.id)}
      conservative_disagreement_count = if first_ident
        working_idents.select{|i| i.id > first_ident.id && id_taxon.ancestor_ids.include?(i.taxon_id)}.size
      else
        0
      end

      {
        :taxon => id_taxon,
        :ident_count => working_idents.select{|i| i.taxon_id == id_taxon.id}.size,
        :cumulative_count => cumulative_count,
        :disagreement_count => disagreement_count,
        :conservative_disagreement_count => conservative_disagreement_count,
        :score => cumulative_count.to_f / (cumulative_count + disagreement_count + conservative_disagreement_count)
      }
    end
  end

  def set_community_taxon(options = {})
    self.community_taxon = get_community_taxon(options)
    true
  end

  def set_community_taxon_before_save
    set_community_taxon(:force => true) if prefers_community_taxon_changed? || taxon_id_changed?
    true
  end

  def self.set_community_taxa(options = {})
    scope = Observation.includes({:identifications => [:taxon]}, :user)
    scope = scope.where(options[:where]) if options[:where]
    scope = scope.by(options[:user]) unless options[:user].blank?
    scope = scope.of(options[:taxon]) unless options[:taxon].blank?
    scope = scope.in_place(options[:place]) unless options[:place].blank?
    scope = scope.in_projects([options[:project]]) unless options[:project].blank?
    start_time = Time.now
    logger = options[:logger] || Rails.logger
    logger.info "[INFO #{Time.now}] Starting Observation.set_community_taxon, options: #{options.inspect}"
    scope.find_each do |o|
      next unless o.identifications.size > 1
      o.set_community_taxon
      unless o.save
        logger.error "[ERROR #{Time.now}] Failed to set community taxon for #{o}: #{o.errors.full_messages.to_sentence}"
      end
    end
    logger.info "[INFO #{Time.now}] Finished Observation.set_community_taxon in #{Time.now - start_time}s, options: #{options.inspect}"
  end

  def community_taxon_rejected?
    return false if prefers_community_taxon == true
    (prefers_community_taxon == false || user.prefers_community_taxa == false)
  end

  def set_taxon_from_community_taxon
    # explicitly opted in
    self.taxon_id = if prefers_community_taxon
      community_taxon_id || owners_identification.try(:taxon_id)
    # obs opted out or user opted out
    elsif prefers_community_taxon == false || !user.prefers_community_taxa?
      owners_identification.try(:taxon_id)
    # implicitly opted in
    else
      community_taxon_id || owners_identification.try(:taxon_id)
    end
    if taxon_id_changed? && (community_taxon_id_changed? || prefers_community_taxon_changed?)
      update_stats(:skip_save => true)
      self.species_guess = if taxon
        taxon.common_name.try(:name) || taxon.name
      else
        nil
      end
    end
    true
  end
  
  def self.obscure_coordinates_for_observations_of(taxon, options = {})
    taxon = Taxon.find_by_id(taxon) unless taxon.is_a?(Taxon)
    return unless taxon
    scope = Observation.of(taxon)
    scope = scope.in_place(options[:place]) if options[:place]
    scope.find_each do |o|
      o.obscure_coordinates
      Observation.where(id: o.id).update_all(
        place_guess: o.place_guess,
        latitude: o.latitude,
        longitude: o.longitude,
        private_latitude: o.private_latitude,
        private_longitude: o.private_longitude,
        geom: o.geom,
        private_geom: o.private_geom
      )
    end
  end
  
  def self.unobscure_coordinates_for_observations_of(taxon)
    taxon = Taxon.find_by_id(taxon) unless taxon.is_a?(Taxon)
    return unless taxon
    Observation.find_observations_of(taxon) do |o|
      o.unobscure_coordinates
      Observation.where(id: o.id).update_all(
        latitude: o.latitude,
        longitude: o.longitude,
        private_latitude: o.private_latitude,
        private_longitude: o.private_longitude,
        geom: o.geom,
        private_geom: o.private_geom
      )
    end
  end

  def self.reassess_coordinates_for_observations_of(taxon, options = {})
    scope = Observation.of(taxon).joins(:taxon)
    scope = scope.in_place(options[:place]) if options[:place]
    scope.find_each do |o|
      o.obscure_coordinates_for_threatened_taxa
      next unless o.coordinates_changed?
      Observation.where(id: o.id).update_all(
        latitude: o.latitude,
        longitude: o.longitude,
        private_latitude: o.private_latitude,
        private_longitude: o.private_longitude,
        geom: o.geom,
        private_geom: o.private_geom
      )
    end
  end
  
  def self.find_observations_of(taxon)
    Observation.joins(:taxon).
      where("observations.taxon_id = ? OR taxa.ancestry LIKE '#{taxon.ancestry}/#{taxon.id}%'", taxon).find_each do |o|
      yield(o)
    end
  end
  
  
  ##### Validations #########################################################
  #
  # Make sure the observation is not in the future.
  #
  def must_be_in_the_past
    return true if observed_on.blank?
    if observed_on > Time.now.in_time_zone(time_zone || user.time_zone).to_date
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
    rescue RuntimeError, ArgumentError
      # ignore parse errors, assume they're not spans
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
    return true if self.taxon_name.blank?
    return true if taxon_id
    self.taxon_id = single_taxon_id_for_name(self.taxon_name)
    true
  end
  
  def set_taxon_from_species_guess
    return true if species_guess =~ /\?$/
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
  
  def set_geom_from_latlon(options = {})
    if longitude.blank? || latitude.blank?
      self.geom = nil
    elsif options[:force] || longitude_changed? || latitude_changed?
      self.geom = "POINT(#{longitude} #{latitude})"
    end
    if private_latitude && private_longitude
      self.private_geom = "POINT(#{private_longitude} #{private_latitude})"
    elsif self.geom
      self.private_geom = self.geom
    else
      self.private_geom = nil
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
      delay(:priority => USER_INTEGRITY_PRIORITY).update_out_of_range
    end
    true
  end
  
  def update_out_of_range
    set_out_of_range
    Observation.where(id: id).update_all(out_of_range: out_of_range)
  end
  
  def set_out_of_range
    if taxon_id.blank? || !georeferenced? || !TaxonRange.exists?(["taxon_id = ?", taxon_id])
      self.out_of_range = nil
      return
    end
    
    # buffer the point to accomodate simplified or slightly inaccurate ranges
    buffer_degrees = OUT_OF_RANGE_BUFFER / (2*Math::PI*Observation::PLANETARY_RADIUS) * 360.0
    
    self.out_of_range = if coordinates_obscured?
      TaxonRange.where(
        "taxon_ranges.taxon_id = ? AND ST_Distance(taxon_ranges.geom, ST_Point(?,?)) > ?",
        taxon_id, private_longitude, private_latitude, buffer_degrees
      ).exists?
    else
      TaxonRange.
        from("taxon_ranges, observations").
        where(
          "taxon_ranges.taxon_id = ? AND observations.id = ? AND ST_Distance(taxon_ranges.geom, observations.geom) > ?",
          taxon_id, id, buffer_degrees
        ).count > 0
    end
  end

  def set_uri
    if uri.blank?
      Observation.where(id: id).update_all(uri: FakeView.observation_url(id))
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
    Observation.where(user_id: user_id).update_all(license: license)
    true
  end

  def update_taxon_counter_caches
    return true unless destroyed? || taxon_id_changed?
    taxon_ids = [taxon_id_was, taxon_id].compact.uniq
    unless taxon_ids.blank?
      Taxon.delay(:priority => INTEGRITY_PRIORITY).update_observation_counts(:taxon_ids => taxon_ids)
    end
    true
  end

  def update_quality_metrics
    if captive_flag.yesish?
      QualityMetric.vote(user, self, QualityMetric::WILD, false)
    elsif captive_flag.noish? && force_quality_metrics
      QualityMetric.vote(user, self, QualityMetric::WILD, true)
    elsif captive_flag.noish? && (qm = quality_metrics.detect{|m| m.user_id == user_id && m.metric == QualityMetric::WILD})
      qm.update_attributes(:agree => true)
    elsif force_quality_metrics && (qm = quality_metrics.detect{|m| m.user_id == user_id && m.metric == QualityMetric::WILD})
      qm.destroy
    end
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
    url = observation_image_url(self, :size => "medium")
    url =~ /^http/ ? url : nil
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
    current_idents = idents.select(&:current?)
    if taxon_id.blank?
      num_agreements    = 0
      num_disagreements = 0
    else
      if node = community_taxon_nodes.detect{|n| n[:taxon].try(:id) == taxon_id}
        num_agreements = node[:cumulative_count]
        num_disagreements = node[:disagreement_count] + node[:conservative_disagreement_count]
        num_agreements -= 1 if current_idents.detect{|i| i.taxon_id == taxon_id && i.user_id == user_id}
      else
        num_agreements    = current_idents.select{|ident| ident.is_agreement?(:observation => self)}.size
        num_disagreements = current_idents.select{|ident| ident.is_disagreement?(:observation => self)}.size
      end
    end
    
    # Kinda lame, but Observation#get_quality_grade relies on these numbers
    self.num_identification_agreements = num_agreements
    self.num_identification_disagreements = num_disagreements
    self.identifications_count = idents.size
    new_quality_grade = get_quality_grade
    self.quality_grade = new_quality_grade
    
    if !options[:skip_save] && (
        num_identification_agreements_changed? ||
        num_identification_disagreements_changed? ||
        quality_grade_changed? ||
        identifications_count_changed?)
      Observation.where(id: id).update_all(
        num_identification_agreements: num_agreements,
        num_identification_disagreements: num_disagreements,
        quality_grade: new_quality_grade,
        identifications_count: identifications_count)
      refresh_check_lists
      refresh_lists
    end
  end
  
  def self.update_stats_for_observations_of(taxon)
    taxon = Taxon.find_by_id(taxon) unless taxon.is_a?(Taxon)
    return unless taxon
    descendant_conditions = taxon.descendant_conditions.to_a
    Observation.includes(:taxon, :identifications).
        select("observations.*").
        joins("LEFT OUTER JOIN taxa otaxa ON otaxa.id = observations.taxon_id").
        joins("LEFT OUTER JOIN identifications idents ON idents.observation_id = observations.id").
        joins("LEFT OUTER JOIN taxa itaxa ON itaxa.id = idents.taxon_id").
        where("otaxa.id = ? OR otaxa.ancestry = ? OR otaxa.ancestry LIKE ? OR itaxa.id = ? OR itaxa.ancestry = ? OR itaxa.ancestry LIKE ?", 
          taxon.id, descendant_conditions[10].val, descendant_conditions[4].val,
          taxon.id, descendant_conditions[10].val, descendant_conditions[4].val).find_each do |o|
      o.set_community_taxon
      o.update_stats(:skip_save => true)
      o.save
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
    acc = public_positional_accuracy || private_positional_accuracy || positional_accuracy
    candidates = Place.containing_lat_lng(lat, lon).sort_by{|p| p.bbox_area || 0}

    # at present we use PostGIS GEOMETRY types, which are a bit stupid about
    # things crossing the dateline, so we need to do an app-layer check.
    # Converting to the GEOGRAPHY type would solve this, in theory.
    # Unfrotinately this does NOT solve the problem of failing to select 
    # legit geoms that cross the dateline. GEOGRAPHY would solve that too.
    candidates.select do |p| 
      # HACK: bbox_contains_lat_lng_acc uses rgeo, which despite having a
      # spherical geometry factory, doesn't seem to allow spherical polygons
      # to use a contains? method, which means it doesn't really work for
      # polygons that cross the dateline, so... skip it until we switch to
      # geography, I guess.
      if p.straddles_date_line?
        true
      else
        p.bbox_contains_lat_lng_acc?(lat, lon, acc)
      end
    end
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
      p.user_id.blank? && (
        [Place::COUNTRY_LEVEL, Place::STATE_LEVEL, Place::COUNTY_LEVEL].include?(p.admin_level) || 
        p.place_type == Place::PLACE_TYPE_CODES['Open Space']
      )
    end
  end

  def intersecting_places
    return [] unless georeferenced?
    lat = private_latitude || latitude
    lon = private_longitude || longitude
    @intersecting_places ||= Place.containing_lat_lng(lat, lon).sort_by{|p| p.bbox_area || 0}
  end

  {
    0     => "Undefined", 
    2     => "Street Segment", 
    4     => "Street", 
    5     => "Intersection", 
    6     => "Street", 
    7     => "Town", 
    8     => "State", 
    9     => "County",
    10    => "Local Administrative Area",
    12    => "Country",
    13    => "Island",
    14    => "Airport",
    15    => "Drainage",
    16    => "Land Feature",
    17    => "Miscellaneous",
    18    => "Nationality",
    19    => "Supername",
    20    => "Point of Interest",
    21    => "Region",
    24    => "Colloquial",
    25    => "Zone",
    26    => "Historical State",
    27    => "Historical County",
    29    => "Continent",
    33    => "Estate",
    35    => "Historical Town",
    36    => "Aggregate",
    100   => "Open Space",
    101   => "Territory"
  }.each do |code, type|
    define_method "place_#{type.underscore}" do
      intersecting_places.detect{|p| p.place_type == code}
    end
    define_method "place_#{type.underscore}_name" do
      send("place_#{type.underscore}").try(:name)
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
    end
  end
  
  def owners_identification
    if identifications.loaded?
      # if idents are loaded, the most recent current identification might be a new record
      identifications.sort_by{|i| i.created_at || 1.minute.from_now}.select {|ident| 
        ident.user_id == user_id && ident.current?
      }.last
    else
      identifications.current.by(user_id).last
    end
  end

  def method_missing(method, *args, &block)
    return super unless method.to_s =~ /^field:/ || method.to_s =~ /^taxon_[^=]+/
    if method.to_s =~ /^field:/
      of_name = method.to_s.split(':').last
      ofv = observation_field_values.detect{|ofv| ofv.observation_field.normalized_name == of_name}
      if ofv
        return ofv.taxon ? ofv.taxon.name : ofv.value
      end
    elsif method.to_s =~ /^taxon_/ && !self.class.instance_methods.include?(method) && taxon
      return taxon.send(method.to_s.gsub(/^taxon_/, ''))
    end
    super
  end

  def respond_to?(method, include_private = false)
    @@class_methods_hash ||= Hash[ self.class.instance_methods.map{ |h| [ h.to_sym, true ] } ]
    @@class_columns_hash ||= Hash[ self.class.column_names.map{ |h| [ h.to_sym, true ] } ]
    if @@class_methods_hash[method.to_sym] || @@class_columns_hash[method.to_sym]
      return super
    end
    return super unless method.to_s =~ /^field:/ || method.to_s =~ /^taxon_[^=]+/
    if method.to_s =~ /^field:/
      of_name = method.to_s.split(':').last
      ofv = observation_field_values.detect{|ofv| ofv.observation_field.normalized_name == of_name}
      return !ofv.blank?
    elsif method.to_s =~ /^taxon_/ && taxon
      return taxon.respond_to?(method.to_s.gsub(/^taxon_/, ''), include_private)
    end
    super
  end

  def merge(reject)
    mutable_columns = self.class.column_names - %w(id created_at updated_at)
    mutable_columns.each do |column|
      self.send("#{column}=", reject.send(column)) if send(column).blank?
    end
    reject.identifications.update_all("current = false")
    merge_has_many_associations(reject)
    reject.destroy
    identifications.group_by{|ident| [ident.user_id, ident.taxon_id]}.each do |pair, idents|
      c = idents.sort_by(&:id).last
      c.update_attributes(:current => true)
    end
    save!
  end

  def create_deleted_observation
    DeletedObservation.create(
      :observation_id => id,
      :user_id => user_id
    )
    true
  end

  def build_observation_fields_from_tags(tags)
    tags.each do |tag|
      np, value = tag.split('=')
      next unless np && value
      namespace, predicate = np.split(':')
      predicate = namespace if predicate.blank?
      of = ObservationField.where("lower(name) = ?", predicate.downcase).first
      next unless of
      next if self.observation_field_values.detect{|ofv| ofv.observation_field_id == of.id}
      if of.datatype == ObservationField::TAXON
        t = Taxon.single_taxon_for_name(value)
        next unless t
        value = t.id
      end
      ofv = ObservationFieldValue.new(observation: self, observation_field: of, value: value)
      self.observation_field_values.build(ofv.attributes) if ofv.valid?
    end
  end

  def fields_addable_by?(u)
    return false unless u.is_a?(User) 
    return true if user.preferred_observation_fields_by == User::PREFERRED_OBSERVATION_FIELDS_BY_ANYONE
    return true if user.preferred_observation_fields_by == User::PREFERRED_OBSERVATION_FIELDS_BY_CURATORS && u.is_curator?
    u.id == user_id
  end

  def set_coordinates
    if self.geo_x.present? && self.geo_y.present? && self.coordinate_system.present?
      # Perform the transformation
      # transfrom from `self.coordinate_system`
      from = RGeo::CoordSys::Proj4.new(CONFIG.coordinate_systems.send(self.coordinate_system.to_sym).proj4)

      # ... to WGS84
      to = RGeo::CoordSys::Proj4.new(WGS84_PROJ4)

      # Returns an array of lat, lon
      transform = RGeo::CoordSys::Proj4.transform_coords(from, to, self.geo_x.to_d, self.geo_y.to_d)

      # Set the transfor
      self.longitude, self.latitude = transform
    end
    true
  end
  
  # Required for use of the sanitize method in
  # ObservationsHelper#short_observation_description
  def self.white_list_sanitizer
    @white_list_sanitizer ||= HTML::WhiteListSanitizer.new
  end
  
  def self.update_for_taxon_change(taxon_change, taxon, options = {}, &block)
    input_taxon_ids = taxon_change.input_taxa.map(&:id)
    scope = Observation.where("observations.taxon_id IN (?)", input_taxon_ids)
    scope = scope.by(options[:user]) if options[:user]
    scope = scope.where("observations.id IN (?)", options[:records].to_a) unless options[:records].blank?
    scope = scope.includes(:user)
    scope.find_each do |observation|
      Identification.create(:user => observation.user, :observation => observation, :taxon => taxon, :taxon_change => taxon_change)
      yield(observation) if block_given?
    end
  end

  # 2014-01 I tried improving performance by loading ancestor taxa for each
  # batch, but it didn't really speed things up much
  def self.generate_csv(scope, options = {})
    fname = options[:fname] || "observations.csv"
    fpath = options[:path] || File.join(options[:dir] || Dir::tmpdir, fname)
    FileUtils.mkdir_p File.dirname(fpath), :mode => 0755
    columns = options[:columns] || CSV_COLUMNS
    CSV.open(fpath, 'w') do |csv|
      csv << columns
      scope.find_each(:batch_size => 500) do |observation|
        csv << columns.map do |c| 
          c = "cached_tag_list" if c == "tag_list"
          observation.send(c) rescue nil
        end
      end
    end
    fpath
  end

  def self.generate_csv_for(record, options = {})
    fname = options[:fname] || "#{record.to_param}-observations.csv"
    fpath = options[:path] || File.join(options[:dir] || Dir::tmpdir, fname)
    tmp_path = File.join(Dir::tmpdir, fname)
    FileUtils.mkdir_p File.dirname(tmp_path), :mode => 0755
    columns = CSV_COLUMNS

    # ensure private coordinates are hidden unless they shouldn't be
    viewer_curates_project = record.is_a?(Project) && record.curated_by?(options[:user])
    viewer_is_owner = record.is_a?(User) && record == options[:user]
    unless viewer_curates_project || viewer_is_owner
      columns = columns.select{|c| c !~ /^private_/}
    end

    # generate the csv
    if record.respond_to?(:generate_csv)
      record.generate_csv(tmp_path, columns, viewer: options[:user])
    else
      scope = record.observations.
        includes(:taxon).
        includes(observation_field_values: :observation_field)
      unless record.is_a?(User) && options[:user] === record
        scope = scope.includes(project_observations: :stored_preferences).
          includes(user: {project_users: :stored_preferences})
      end
      generate_csv(scope, :path => tmp_path, :fname => fname, :columns => columns, :viewer => options[:user])
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

  # share this (and any subsequent) observations on facebook
  def share_on_facebook(options = {})
    fb_api = user.facebook_api
    return nil unless fb_api
    observations_to_share = if options[:single]
      [self]
    else
      Observation.includes(:taxon).limit(100).
        where(:user_id => user_id).
        where("observations.id >= ?", id).
        where("observations.taxon_id is not null")
    end
    observations_to_share.each do |o|
      fb_api.put_connections("me", "#{CONFIG.facebook.namespace}:record", :observation => FakeView.observation_url(o))
    end
  rescue OAuthException => e
    Rails.logger.error "[ERROR #{Time.now}] Failed to share Observation #{id} on Facebook: #{e}"
  end

  # share this (and any subsequent) observations on twitter
  # if we're sharing more than one observation, this aggregates them into one tweet
  def share_on_twitter(options = {})
    u = self.user
    twit_api = u.twitter_api
    return nil unless twit_api
    observations_to_share = if options[:single]
      [self]
    else
      Observation.where(:user_id => u.id).where(["id >= ?", id]).limit(100)
    end
    observations_to_share_count = observations_to_share.count
    tweet_text = "I added "
    tweet_text += observations_to_share_count > 1 ? "#{observations_to_share_count} observations" : "an observation"
    url = if observations_to_share_count == 1
      FakeView.observation_url(self)
    else
      dates = observations_to_share.map(&:observed_on).uniq.compact
      if dates.size == 1
        d = dates.first
        FakeView.calendar_date_url(u.login, d.year, d.month, d.day)
      else
        FakeView.observations_by_login_url(u.login)
      end
    end
    url = if url =~ /\?/
      "#{url}&#{id}"
    else
      "#{url}?#{id}"
    end
    tweet_text += " to #{SITE_NAME} #{url}"
    twit_api.update(tweet_text)
  end

  # Share this and any future observations on twitter and/or fb (depending on user preferences)
  def queue_for_sharing
    u = self.user
    ["facebook","twitter"].each do |provider_name|
      explicitly_shared = send("#{provider_name}_sharing") == "1"
      explicitly_not_shared = send("#{provider_name}_sharing") == "0"
      implicitly_shared = u.prefs["share_observations_on_#{provider_name}"]
      user_wants_to_share = explicitly_shared || (implicitly_shared && !explicitly_not_shared)
      if u.send("#{provider_name}_identity") && user_wants_to_share
        # don't queue up more than one job for the given sharing medium. 
        # when the job is run, it will also share any observations made since this one. 
        # observation aggregation for twitter happens in share_on_twitter.
        # fb aggregation happens on their end via open graph aggregations.
        self.delay(priority: USER_INTEGRITY_PRIORITY, run_at: 1.hour.from_now,
          unique_hash: { "Observation::share_on_#{provider_name}": u.id }).
          send("share_on_#{provider_name}")
      end
    end
    true
  end

  def update_public_positional_accuracy
    update_column(:public_positional_accuracy, calculate_public_positional_accuracy)
  end

  def calculate_public_positional_accuracy
    if coordinates_obscured?
      if positional_accuracy.blank?
        M_TO_OBSCURE_THREATENED_TAXA
      else
        [ positional_accuracy, M_TO_OBSCURE_THREATENED_TAXA, 0 ].max
      end
    elsif !positional_accuracy.blank?
      positional_accuracy
    end
  end

  def inaccurate_location?
    if metric = quality_metric_score(QualityMetric::LOCATION)
      return metric <= 0.5
    end
    false
  end

  def update_mappable
    update_column(:mappable, calculate_mappable)
  end

  def calculate_mappable
    return false if latitude.blank? && longitude.blank?
    return false if public_positional_accuracy && public_positional_accuracy > M_TO_OBSCURE_THREATENED_TAXA
    return false if captive
    return false if inaccurate_location?
    true
  end

  def update_observations_places
    Observation.connection.transaction do
      ObservationsPlace.where(observation_id: id).delete_all
      Place.including_observation(self).each do |place|
        ObservationsPlace.create(observation: self, place: place)
      end
    end
  end

  def observation_photos_finished_processing
    observation_photos.select do |op|
      ! (op.photo.is_a?(LocalPhoto) && op.photo.processing?)
    end
  end

  def self.as_csv(scope, methods)
    CSV.generate do |csv|
      csv << methods
      scope.each do |item|
        csv << methods.map{ |m| item.send(m) }
      end
    end
  end

end
