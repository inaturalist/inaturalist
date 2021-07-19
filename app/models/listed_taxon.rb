#
# Join model for Lists and Taxa.  In addition to storing a reference to the
# last observed taxon (saving some db time), this model's validation makes
# sure a taxon passes all of a list's ListRules.
#
class ListedTaxon < ActiveRecord::Base
  has_subscribers destroy_callback: :commit
  
  belongs_to :list
  belongs_to :taxon
  belongs_to :first_observation,
             :class_name => 'Observation', 
             :foreign_key => 'first_observation_id'
  belongs_to :last_observation,
             :class_name => 'Observation', 
             :foreign_key => 'last_observation_id'
  belongs_to :user # creator
  
  has_updater
  has_many :comments, :as => :parent, :dependent => :destroy
  
  # check list assocs
  belongs_to :place
  belongs_to :simple_place,
    -> { select(:id, :name, :display_name, :code, :bbox_area, :ancestry) },
    foreign_key: :place_id,
    class_name: "Place"
  belongs_to :taxon_range # if listed taxon was created b/c of a range intersection
  belongs_to :source # if added b/c of a published source
  
  before_validation :nilify_blanks
  before_validation :update_cache_columns
  before_create :set_place_id
  before_create :set_updater_id
  before_save :set_user_id
  before_save :set_source_id
  before_create :set_establishment_means
  before_save :set_primary_listing
  before_create :check_primary_listing
  after_save :update_cache_columns_for_check_list
  after_save :propagate_establishment_means
  after_save :remove_other_primary_listings
  after_save :update_attributes_on_related_listed_taxa
  after_save :index_taxon
  after_save :log_create_if_taxon_id_changed
  after_commit :expire_caches
  after_commit :reindex_observations_later
  after_create :sync_parent_check_list
  after_create :sync_species_if_infraspecies
  after_create :log_create
  before_destroy :set_old_list
  before_destroy :log_destroy
  after_destroy :reassign_primary_listed_taxon
  
  scope :by_user, lambda {|user| joins(:list).where("lists.user_id = ?", user)}

  scope :order_by, lambda {|order_by|
    case order_by
    when "alphabetical"
      joins(:taxon).order("taxa.name ASC")
    when "taxonomic"
      joins(:taxon).order("taxa.ancestry ASC, taxa.id ASC")
    else
      {} # default to id asc ordering
    end
  }
  
  scope :filter_by_taxon, lambda { |filter_taxon_id, self_and_ancestor_ids|
    # explicit join so Arel doesn't alias the taxa table, breaking the where clause
    joins("INNER JOIN taxa taxon_filter ON (listed_taxa.taxon_id=taxon_filter.id)").
      where("listed_taxa.taxon_id = ? OR taxon_filter.ancestry = ? OR taxon_filter.ancestry LIKE ?",
      filter_taxon_id, self_and_ancestor_ids, "#{self_and_ancestor_ids}/%")
  }
  scope :filter_by_taxa, lambda {|search_taxon_ids| where("listed_taxa.taxon_id IN (?)", search_taxon_ids)}
  scope :find_listed_taxa_from_default_list, lambda{|place_id| where("listed_taxa.place_id = ? AND primary_listing = ?", place_id, true)}
  scope :filter_by_list, lambda {|list_id| where("list_id = ?", list_id)}

  scope :filter_by_place_and_not_list, lambda {|place_id, list_id| where("place_id = ? AND list_id != ? AND taxon_id IS NOT NULL", place_id, list_id)}

  scope :unconfirmed, -> { where("last_observation_id IS NULL") }
  scope :confirmed, -> { where("last_observation_id IS NOT NULL") }
  scope :confirmed_and_not_place_based, -> { where("last_observation_id IS NOT NULL AND place_id IS NULL") }
  scope :with_establishment_means, lambda{|establishment_means|
    means = if establishment_means == "native"
      NATIVE_EQUIVALENTS
    elsif establishment_means == "introduced"
      INTRODUCED_EQUIVALENTS
    elsif !establishment_means.is_a?(Array)
      [establishment_means]
    end
    where("establishment_means IN (?)", means)
  }

  scope :from_place_or_list, lambda{|place_id, list_id| where("(listed_taxa.place_id = ? OR listed_taxa.list_id = ?)", place_id, list_id)}
  scope :from_place_or_list_with_observed_from_place, lambda{|place_id, list_id| where("((place_id = ?) OR (list_id = ? AND last_observation_id IS NULL))", place_id, list_id)}

  scope :acceptable_taxa, lambda{|taxa_ids| where("listed_taxa.taxon_id IN (?)", taxa_ids)}

  scope :with_occurrence_status_level, lambda{|occurrence_status_level| where("occurrence_status_level = ?", occurrence_status_level)}

  scope :with_occurrence_status_levels_approximating_absent, -> { where("occurrence_status_level IN (10, 20)") }
  scope :with_occurrence_status_levels_approximating_present, -> { where("occurrence_status_level NOT IN (10, 20) OR occurrence_status_level IS NULL") }

  scope :with_threatened_status, ->(place_id) {
    joins(:taxon).
    joins("INNER JOIN conservation_statuses cs ON cs.taxon_id = listed_taxa.taxon_id").
    where("cs.iucn >= #{Taxon::IUCN_NEAR_THREATENED} AND (cs.place_id IS NULL OR cs.place_id::text IN (#{place_ancestor_ids_sql(place_id)}))").
    select("DISTINCT ON (taxa.ancestry || '/' || listed_taxa.taxon_id, listed_taxa.observations_count) listed_taxa.*").
    order("taxa.ancestry || '/' || listed_taxa.taxon_id, listed_taxa.observations_count")
  }
  scope :with_species, -> { joins(:taxon).where(taxa: { rank_level: 10 }) }
  
  scope :excluding_infraspecies, -> { joins(:taxon).where("taxa.rank_level >= 10 ") }
  
  #with taxonomic status (by itself)
  scope :with_taxonomic_status, ->(taxonomic_status) {
    # this would be a better way to do this, but it causes Rails 4 to freak when it gets nested in a subselect
    # joins(:taxon).where(taxa: { is_active: (taxonomic_status ? 't' : 'f') } )
    joins("INNER JOIN taxa t1 ON t1.id = listed_taxa.taxon_id").where("t1.is_active = ?", taxonomic_status ? 't' : 'f')
  }
  #with iconic taxon filter (by itself)
  scope :filter_by_iconic_taxon, ->(iconic_taxon_id) {
    # same problem with subselects as above
    joins("INNER JOIN taxa taxa_filter_by_iconic_taxon ON (listed_taxa.taxon_id = taxa_filter_by_iconic_taxon.id)").
    where(taxa_filter_by_iconic_taxon: { iconic_taxon_id: iconic_taxon_id })
  }
  #both iconic taxon filter and taxonomic status
  scope :with_taxonomic_status_and_iconic_taxon, ->(taxonomic_status, iconic_taxon_id) {
    # same problem with subselects as above
    joins("INNER JOIN taxa taxa_with_status_and_iconic_taxon ON (listed_taxa.taxon_id = taxa_with_status_and_iconic_taxon.id)").
    where(taxa_with_status_and_iconic_taxon: {
      is_active: (taxonomic_status ? 't' : 'f'),
      iconic_taxon_id: iconic_taxon_id }
    )
  }

  # Queries listed taxa that represent leaves in the taxonomic tree described
  # by the list. So if the list contains class Mammalia, species Homo sapiens,
  # and kingdom Plantae, the leaves will be Homo sapiens and Plantae, since
  # Mammalia is on the same branch as Homo sapiens but further toward the
  # root, while Plantae is the end of its own branch. This works by splitting
  # all the ancestries represented by the original query using
  # regexp_split_to_table, so that each individual ancestor ID is a single row
  # in a join table. Since those are *only* the ancestors, if you join the
  # original query on taxon_id and select those that do *not* have a matching
  # taxon in the ancestor join table, those are the leaves.
  scope :with_leaves, lambda{|scope_to_sql|
    # generate the ancestor IDs subquery
    ancestor_ids_sql = scope_to_sql.gsub(/^(S.*)\*/,
      "SELECT DISTINCT regexp_split_to_table(branch_taxa.ancestry, '/') AS ancestor_id")
    # create a new alias for joining with taxa
    if ancestor_ids_sql.match(/ WHERE /)
      ancestor_ids_sql = ancestor_ids_sql.gsub(/ WHERE /,
        " INNER JOIN taxa branch_taxa ON listed_taxa.taxon_id=branch_taxa.id WHERE ")
    else
      ancestor_ids_sql = ancestor_ids_sql +
        " INNER JOIN taxa branch_taxa ON listed_taxa.taxon_id=branch_taxa.id"
    end
    # join ancestors on taxon_id
    join = <<-SQL
      LEFT JOIN (
        #{ancestor_ids_sql}
      AND branch_taxa.rank_level >= 10
      ) AS ancestor_ids ON listed_taxa.taxon_id::text = ancestor_ids.ancestor_id
    SQL
    # filter by listed_taxa where the listed_taxa.taxon_id is not present
    # among the ancestors, i.e. it is a leaf
    excluding_infraspecies.joins(join).where("ancestor_ids.ancestor_id IS NULL")
  }
  
  ALPHABETICAL_ORDER = "alphabetical"
  TAXONOMIC_ORDER = "taxonomic"
  ORDERS = [ALPHABETICAL_ORDER, TAXONOMIC_ORDER]
  OCCURRENCE_STATUS_LEVELS = {
    60 => "present",
    50 => "common",
    40 => "uncommon",
    30 => "irregular",
    20 => "doubtful",
    10 => "absent"
  }
  OCCURRENCE_STATUS_LEVELS_BY_NAME = OCCURRENCE_STATUS_LEVELS.invert
  OCCURRENCE_STATUSES = OCCURRENCE_STATUS_LEVELS.values
  OCCURRENCE_STATUS_DESCRIPTIONS = ActiveSupport::OrderedHash.new
  OCCURRENCE_STATUS_DESCRIPTIONS["present" ] =  "occurs in the area"
  OCCURRENCE_STATUS_DESCRIPTIONS["common" ] =  "occurs frequently"
  OCCURRENCE_STATUS_DESCRIPTIONS["uncommon" ] =  "occurs regularly, but in small numbers; requires careful searching of proper habitat" 
  OCCURRENCE_STATUS_DESCRIPTIONS["irregular" ] =  "presence unpredictable, including vagrants; may be common in some years and absent others"
  OCCURRENCE_STATUS_DESCRIPTIONS["doubtful" ] =  "presumed to occur, but doubt exists over the evidence"
  OCCURRENCE_STATUS_DESCRIPTIONS["absent" ] =  "does not occur in the area"
  
  OCCURRENCE_STATUS_LEVELS.each do |level, name|
    const_set name.upcase, level
    define_method "#{name}?" do
      level == occurrence_status_level
    end
  end
  PRESENT_EQUIVALENTS = [PRESENT, COMMON, UNCOMMON]
  
  ESTABLISHMENT_MEANS = %w(native endemic introduced)
  ESTABLISHMENT_MEANS_DESCRIPTIONS = ActiveSupport::OrderedHash.new
  ESTABLISHMENT_MEANS_DESCRIPTIONS["native"] = "evolved in this region or arrived by non-anthropogenic means"
  ESTABLISHMENT_MEANS_DESCRIPTIONS["endemic"] = "native and occurs nowhere else"
  ESTABLISHMENT_MEANS_DESCRIPTIONS["introduced"] = "arrived in the region via anthropogenic means"
  
  ESTABLISHMENT_MEANS.each do |means|
    const_set means.upcase, means
    define_method "#{means}?" do
      establishment_means == means
    end
  end
  
  NATIVE_EQUIVALENTS = %w(native endemic)
  INTRODUCED_EQUIVALENTS = %w(introduced)
  CHECK_LIST_FIELDS = %w(place_id occurrence_status establishment_means)

  validates_presence_of :list_id, :taxon_id
  validates_uniqueness_of :taxon_id,
                          :scope => :list_id,
                          :message => "is already on this list"
  validates_length_of :description, :maximum => 1000, :allow_blank => true
  validates_inclusion_of :occurrence_status_level, :in => OCCURRENCE_STATUS_LEVELS.keys, :allow_blank => true
  validates_inclusion_of :establishment_means, :in => ESTABLISHMENT_MEANS, :allow_blank => true, :allow_nil => true
  validate :not_on_a_comprehensive_check_list, :on => :create
  validate :absent_only_if_not_confirming_observations
  validate :list_rules_pass
  validate :taxon_matches_observation
  validate :check_list_editability
  validate :establishment_means_allowed

  attr_accessor :skip_sync_with_parent,
                :skip_species_for_infraspecies,
                :skip_update_cache_columns,
                :force_update_cache_columns,
                :extra,
                :html,
                :old_list,
                :force_trickle_down_establishment_means,
                :skip_index_taxon
  
  def ancestry
    taxon.ancestry
  end
  
  def to_s
    "<ListedTaxon #{self.id}: taxon_id: #{self.taxon_id} list_id: #{self.list_id} place_id: #{place_id}>"
  end
  
  def to_plain_s
    "#{taxon.default_name.name} on #{list.title}"
  end
  
  def not_on_a_comprehensive_check_list
    return true unless taxon
    return true unless list.is_a?(CheckList)
    return true if first_observation_id || last_observation_id
    target_place = place || list.place
    return true unless existing_comprehensive_list
    unless existing_comprehensive_listed_taxon
      errors.add(:taxon_id, "isn't on the comprehensive list \"#{existing_comprehensive_list.title}\" (#{existing_comprehensive_list.id})")
    end
    true
  end
  
  def existing_comprehensive_list
    return nil unless list.is_a?(CheckList)
    return @existing_comprehensive_list unless @existing_comprehensive_list.blank?
    places = [self.place || list.place]
    while !places.last.nil? do
      places << places.last.parent
    end
    places.compact!
    @existing_comprehensive_list = CheckList.where([
      "comprehensive = 't' AND id != ? AND taxon_id IN (?) AND place_id IN (?)", 
      list_id, taxon.ancestor_ids, places]).first
  end
  
  def existing_comprehensive_listed_taxon
    return nil unless existing_comprehensive_list
    @existing_listed_taxon ||= existing_comprehensive_list.listed_taxa.where(taxon_id: taxon_id).first
  end
  
  def absent_only_if_not_confirming_observations
    return true unless occurrence_status_level_changed?
    return true unless absent?
    if first_observation || last_observation
      errors.add(:occurrence_status_level, "can't be absent if there are confirming observations")
    end
    true
  end

  def list_rules_pass
    # don't bother if validates_presence_of(:taxon) has already failed
    if !errors.include?(:taxon) && taxon
      if list 
        list.rules.each do |rule|
          if rule.operator == "observed_in_place?" && manually_added?
            next
          end
          errors.add(:base, "#{taxon.to_plain_s} is not #{rule.terms}") unless rule.validates?(self)
        end
      end
    end
  end

  def taxon_matches_observation
    return false if taxon.blank?
    if last_observation
      if last_observation.taxon_id.blank? || !(
          taxon_id == last_observation.taxon_id || 
          taxon.ancestor_of?(last_observation.taxon) || 
          last_observation.taxon.ancestor_of?(taxon))
        if taxon_matches_curator_identification? #cases where project listed_taxon is based on curator_id
          return true
        end
        errors.add(:taxon_id, "must be the same as the last observed taxon, #{last_observation.taxon.try(:to_plain_s)}")
      end
    end
  end
  
  def taxon_matches_curator_identification?
    unless list.is_a?(ProjectList) && last_observation
      return false
    end
    unless po = ProjectObservation.where(:project_id => list.project_id, :observation_id => last_observation.id).first
      return false
    end
    unless ident = Identification.find_by_id(po.curator_identification_id)
      return false
    end
    if ident.taxon_id.blank? || !(
        taxon_id == ident.taxon_id || 
        taxon.ancestor_of?(ident.taxon) || 
        ident.taxon.ancestor_of?(taxon))
      return false
    end
    return true
  end
  
  def check_list_editability
    if list.is_a?(CheckList)
      if (list.comprehensive? || list.user) && user && user != list.user && !user.is_curator?
        errors.add(:user, "must be the list creator or a curator")
      end
    else
      CHECK_LIST_FIELDS.each do |field|
        errors.add(field, "can only be set for check lists") unless send(field).blank?
      end
    end
  end

  def establishment_means_allowed
    return true unless endemic?
    if place && ( ( place.admin_level && place.admin_level <= Place::CONTINENT_LEVEL ) || ( place.place_type == Place::CONTINENT ) )
      errors.add( :establishment_means, "can't be endemic for continents" )
    end
    true
  end
  
  def set_old_list
    @old_list = self.list
  end
  
  def set_user_id
    self.user_id ||= list.user_id if list
    true
  end
  
  def set_source_id
    self.source_id ||= list.source_id if list
    true
  end
  
  def set_updater_id
    self.updater_id ||= user_id
    true
  end
  
  def set_place_id
    self.place_id = self.list.place_id if list.is_a?(CheckList)
    true
  end

  def set_establishment_means
    return true unless establishment_means.blank?
    return true if place.blank?
    if introduced_ancestor_listed_taxon = ListedTaxon.
        where("place_id IN (?)", place.ancestor_ids).
        where(:taxon_id => taxon_id).
        where("establishment_means IN (?)", INTRODUCED_EQUIVALENTS).
        first
      self.establishment_means = introduced_ancestor_listed_taxon.establishment_means
    elsif native_child_listed_taxon = ListedTaxon.joins(:place).
        where(place.descendant_conditions).
        where(:taxon_id => taxon_id).
        where("establishment_means IN (?)", NATIVE_EQUIVALENTS).
        first
      self.establishment_means = native_child_listed_taxon.establishment_means
    end
    true
  end

  def set_primary_listing
    self.primary_listing = false unless can_set_as_primary?
    true
  end
  
  def sync_parent_check_list
    return true unless list.is_a?(CheckList)
    return true if skip_sync_with_parent
    list.delay(priority: INTEGRITY_PRIORITY,
      unique_hash: { "CheckList::sync_with_parent": list_id }).
      sync_with_parent(:time_since_last_sync => updated_at)
    true
  end
  
  def sync_species_if_infraspecies
    return true if skip_species_for_infraspecies
    return true unless list.is_a?(CheckList) && taxon
    return true unless taxon.infraspecies?
    ListedTaxon.delay(priority: INTEGRITY_PRIORITY, run_at: 1.hour.from_now,
      queue: "slow", unique_hash: { "ListedTaxon::species_for_infraspecies": id }).
      species_for_infraspecies(id)
    true
  end

  def index_taxon
    unless skip_index_taxon
      Taxon.delay(priority: INTEGRITY_PRIORITY, run_at: 1.hour.from_now,
        unique_hash: { "Taxon::elastic_index": taxon_id }).
        elastic_index!(ids: [taxon_id])
    end
  end

  def update_cache_columns
    return true if skip_update_cache_columns
    return true if list.is_a?(CheckList) && (!force_update_cache_columns || place_id.blank?)
    return true if list.is_a?(CheckList) && !primary_listing
    set_cache_columns
    true
  end
  
  def set_cache_columns
    return unless taxon_id
    if cc = cache_columns
      self.first_observation_id, self.last_observation_id,
      self.observations_count = cc
    end
  end
  
  def update_cache_columns_for_check_list
    return true if skip_update_cache_columns
    return true unless list.is_a?(CheckList)
    if primary_listing
      unless force_update_cache_columns
        ListedTaxon.delay(priority: INTEGRITY_PRIORITY, run_at: 1.hour.from_now,
          queue: "slow", unique_hash: { "ListedTaxon::update_cache_columns_for": id }).
          update_cache_columns_for(id)
      end
    elsif primary_listed_taxon
      primary_listed_taxon.update_attributes_on_related_listed_taxa
    end
    true
  end

  def propagate_establishment_means
    return true unless list.is_a?(CheckList)
    if force_trickle_down_establishment_means.yesish?
      trickle_down_establishment_means(:force => true)
    end
    return true unless establishment_means_changed? && !establishment_means.blank?
    bubble_up_establishment_means if native?
    if introduced? && force_trickle_down_establishment_means.blank?
      trickle_down_establishment_means
    end
    true
  end

  def bubble_up_establishment_means
    ListedTaxon.where("taxon_id = ? AND establishment_means IS NULL AND place_id IN (?)",
      taxon_id, place.ancestor_ids).update_all(establishment_means: establishment_means)
  end

  def trickle_down_establishment_means(options = {})
    sql = <<-SQL
      UPDATE listed_taxa
      SET establishment_means = '#{establishment_means}'
      FROM places
      WHERE 
        listed_taxa.place_id = places.id
        #{"AND (establishment_means IS NULL OR establishment_means = '')" unless options[:force]}
        AND listed_taxa.taxon_id = #{taxon_id}
        AND (#{Place.send(:sanitize_sql, place.descendant_conditions.to_sql)})
    SQL
    ActiveRecord::Base.connection.execute(sql)
  end
  
  def has_atlas_or_complete_set?(options = {})
    return false unless list.is_a?( CheckList ) && list.is_default?
    return false unless [Place::COUNTRY_LEVEL, Place::STATE_LEVEL, Place::COUNTY_LEVEL].include? place.admin_level
    relevant_taxon = taxon
    if options[:taxon_was]
      relevant_taxon = Taxon.where(id: options[:taxon_was]).first
    end
    return false unless relevant_taxon
    place_ancestor_place_ids = place.ancestor_place_ids.nil? ? [place_id] : place.ancestor_place_ids
    atlas_ids = Atlas.where( "is_active = true AND taxon_id IN (?)", relevant_taxon.self_and_ancestor_ids ).pluck( :id )
    # there are atlases for this taxon or ancestors and this place isn't
    # exploded for all matching atlases, therefore this action is relevant
    # to some atlas and should be logged
    return true if atlas_ids.any? &&
      ExplodedAtlasPlace.where( "atlas_id IN ( ? )", atlas_ids ).
        where( place_id: place.id ).count < atlas_ids.length
    cs = CompleteSet.
      where( "is_active = true").
      where("taxon_id IN ( ? ) AND place_id IN ( ? )", relevant_taxon.self_and_ancestor_ids, place_ancestor_place_ids ).
      count
    return true if cs > 0
    false
  end
  
  def log_create
    if has_atlas_or_complete_set?
      ListedTaxonAlteration.create(
        taxon_id: taxon_id,
        user_id: user_id,
        place_id: place_id,
        action: "listed"
      )
    end
  end
  
  def log_destroy
    if has_atlas_or_complete_set?
      updater_id = updater.nil? ? nil : updater.id
      ListedTaxonAlteration.create(
        taxon_id: taxon_id,
        user_id: updater_id,
        place_id: place_id,
        action: "unlisted"
      )
    end
  end
  
  def log_create_if_taxon_id_changed
    return true unless taxon_id_changed?
    return true if taxon_id_was.nil?
    if has_atlas_or_complete_set?(taxon_was: taxon_id_was)
      ListedTaxonAlteration.create(
        taxon_id: taxon_id,
        user_id: nil,
        place_id: place_id,
        action: "listed"
      )
    end
  end

  # Retrieve the first and last observations and the month counts. Note that
  # at present first_observation has a different meaning depending on the
  # list: for check lists it means the first observation added to iNat (i.e.
  # sorted by ID), but for everything else it means first observation by date
  # observed. Not great, but it means the first observer for places rewards
  # people for being the first to add to the site, and the user list firsts on
  # the calendar views shows the first time you saw a taxon.
  def cache_columns
    return unless list
    return unless list.is_a?( CheckList )
    Logstasher.write_hash(
      "@timestamp": Time.now,
      subtype: "ListedTaxon#cache_columns",
      model: "ListedTaxon",
      model_id: self.id,
      model_method: "ListedTaxon::cache_columns"
    )
    # get the specific options for this list type
    options = list.cache_columns_options(self)
    ListedTaxon.earliest_and_latest_ids(options)
  end

  def self.earliest_and_latest_ids(options)
    earliest_id = nil
    latest_id = nil
    return [ nil, nil, 0 ] unless options[:filters]
    search_params = { filters: options[:filters].dup }
    search_params[:size] = 1
    if options[:range_filters]
      search_params[:filters] += options[:range_filters]
    end
    begin
      # fetch the total and the earliest and latest observations
      # in a single ES query with the top_hits aggregation
      rs = Observation.elastic_search(search_params.merge(
        size: 0,
        track_total_hits: true,
        aggregate: {
          earliest: {
            top_hits: {
              sort: [
                { (options[:earliest_sort_field] || "observed_on") => { order: "asc", unmapped_type: "long" } },
                { id: :asc }
              ],
              _source: { includes: [ "id" ] },
              size: 1
            }
          },
          latest: {
            top_hits: {
              sort: [
                { observed_on: { order: "desc", unmapped_type: "long" } },
                { id: :desc }
              ],
              _source: { includes: [ "id" ] },
              size: 1
            }
          }
        }
      ))
      if rs && rs.total_entries > 0 && rs.response.aggregations
        earliest_id = rs.response.aggregations.earliest.hits.hits[0]._source.id
        latest_id = rs.response.aggregations.latest.hits.hits[0]._source.id
        total = rs.total_entries
      end
      [ earliest_id, latest_id, total || 0]
    rescue Elasticsearch::Transport::Transport::Errors::NotFound,
           Elasticsearch::Transport::Transport::Errors::BadRequest => e
      Logstasher.write_exception(e, reference: "ListedTaxon.earliest_and_latest_ids failed")
      Rails.logger.error "[Error] ListedTaxon::earliest_and_latest_ids failed: #{ e }"
      Rails.logger.error "Backtrace:\n#{ e.backtrace[0..30].join("\n") }\n..."
      [ nil, nil, 0 ]
    end
  end

  def self.update_cache_columns_for(lt)
    lt = ListedTaxon.find_by_id(lt) unless lt.is_a?(ListedTaxon)
    return nil unless lt
    lt.set_cache_columns
    ListedTaxon.where(id: lt.id).update_all(
      first_observation_id: lt.first_observation_id,
      last_observation_id: lt.last_observation_id,
      observations_count: lt.observations_count)
  end
  
  def self.species_for_infraspecies(lt)
    lt = ListedTaxon.includes(:taxon,:place).find_by_id(lt) unless lt.is_a?(ListedTaxon)
    return nil unless lt
    return nil unless taxon = lt.taxon
    return nil unless place = lt.place
    return nil unless parent = taxon.parent
    return true if species = ListedTaxon.where(:taxon_id => parent.id, :place_id => place.id).first
    lt = ListedTaxon.new(
      :taxon_id => parent.id,
      :place_id => place.id,
      :list_id => lt.place.check_list_id
    )
    lt.save
  end

  def self.get_defaults_for_taxon_place( place,taxon, options = { } )
    options[:limit] ||= 100
    options[:limit] = 200 if options[:limit] > 200
    taxon = Taxon.find_by_id( taxon ) unless taxon.is_a?( Taxon )
    return unless taxon
    place = Place.find_by_id( place ) unless place.is_a?( Place )
    return unless place
    place_descendant_ids = place.descendants.
      where( "admin_level IN ( ? )", [Place::COUNTRY_LEVEL, Place::STATE_LEVEL, Place::COUNTY_LEVEL] ).pluck( :id )
    place_with_descendant_ids = [ place.id, place_descendant_ids ].compact.flatten
    lt = ListedTaxon.includes( :place, :taxon ).joins( { list: :check_list_place } ).where( "lists.type = 'CheckList'" ).
    where( "listed_taxa.taxon_id IN ( ? )", taxon.taxon_ancestors_as_ancestor.pluck(:taxon_id) ).
    where( "listed_taxa.place_id IN ( ? )", place_with_descendant_ids ).limit( options[:limit] )
  end

  def nilify_blanks
    %w(establishment_means occurrence_status_level).each do |col|
      send("#{col}=", nil) if send(col).blank?
    end
    true
  end
  
  def occurrence_status
    OCCURRENCE_STATUS_LEVELS[occurrence_status_level]
  end

  def occurrence_status=(status)
    self.occurrence_status_level = OCCURRENCE_STATUS_LEVELS_BY_NAME[status]
  end

  def is_present?
    PRESENT_EQUIVALENTS.include?( occurrence_status_level ) || occurrence_status_level.blank?
  end

  def is_absent?
    !is_present?
  end
  
  def editable_by?(target_user)
    list.editable_by?(target_user)
  end
  
  def removable_by?(target_user)
    return false unless target_user
    return true if user == target_user
    return true if list.is_a?(CheckList) && target_user.admin?
    return true if list.is_a?(ProjectList) && list.project.curated_by?(target_user)
    return true if citation_object.blank?
    citation_object == target_user
  end
  
  def citation_object
    source || taxon_range || first_observation || last_observation || user
  end
  
  def auto_removable_from_check_list?
    list.is_a?(CheckList) &&
      first_observation_id.blank? &&
      last_observation_id.blank? &&
      taxon_range_id.blank? &&
      source_id.blank? &&
      !user_id && 
      !updater_id && 
      comments_count.to_i == 0 &&
      list.is_default? &&
      !has_atlas_or_complete_set?
  end
  
  def introduced?
    INTRODUCED_EQUIVALENTS.include?(establishment_means)
  end
  
  def native?
    NATIVE_EQUIVALENTS.include?(establishment_means)
  end
  
  def endemic?
    establishment_means == "endemic"
  end
  
  def taxon_name
    taxon.name
  end

  def taxon_common_name
    taxon.common_name.try(:name)
  end

  def user_login
    user.try(:login)
  end

  def expire_caches
    return unless list.is_a?(CheckList)
    ctrl = ActionController::Base.new
    ctrl.expire_fragment(List.icon_preview_cache_key(list_id))
    ListedTaxon::ORDERS.each do |order|
      ctrl.expire_fragment(FakeView.url_for(:controller => 'observations', :action => 'add_from_list', :id => list_id, :order => order))
    end
    if !place_id.blank? && manually_added
      I18N_SUPPORTED_LOCALES.each do |locale|
        ctrl.send( :expire_action, FakeView.url_for( controller: "places", action: "cached_guide", id: place_id, locale: locale ) )
        ctrl.send( :expire_action, FakeView.url_for( controller: "places", action: "cached_guide", id: place.slug, locale: locale ) ) if place
      end
    end
    if list
      ctrl.expire_page FakeView.list_path(list_id, :format => 'csv')
      ctrl.expire_page FakeView.list_show_formatted_view_path(list_id, :format => 'csv', :view_type => 'taxonomic')
      ctrl.expire_page FakeView.list_path(list, :format => 'csv')
      ctrl.expire_page FakeView.list_show_formatted_view_path(list, :format => 'csv', :view_type => 'taxonomic')
    end
    true
  end

  def self.expire_caches_for(taxon)
    taxon = Taxon.find_by_id(taxon) unless taxon.is_a?(Taxon)
    return unless taxon
    taxon.listed_taxa.includes(:list, :place).find_each do |lt|
      lt.expire_caches
    end
  end
  
  def merge(reject)
    mutable_columns = self.class.column_names - %w(id created_at updated_at)
    mutable_columns.each do |column|
      self.send("#{column}=", reject.send(column)) if send(column).blank?
    end
    merge_has_many_associations(reject)
    reject.destroy
    save!
  end

  def observed_in_place?
    p = place || list.place
    return false unless p
    scope = Observation.joins(:observations_places).where("observations_places.place_id = ?", p).of(taxon)
    scope.exists?
  end
  
  def self.merge_duplicates(options = {})
    debug = options.delete(:debug)
    where = options.map{|k,v| "#{k} = #{v}"}.join(' AND ') unless options.blank?
    sql = <<-SQL
      SELECT list_id, taxon_id, array_agg(id) AS ids, count(*) 
      FROM listed_taxa
      #{"WHERE #{where}" if where}
      GROUP BY list_id, taxon_id HAVING count(*) > 1
    SQL
    puts "Finding listed taxa WHERE #{where}" if debug
    connection.execute(sql.gsub(/\s+/, ' ').strip).each do |row|
      to_merge_ids = row['ids'].to_s.gsub(/[\{\}]/, '').split(',').sort
      lt = ListedTaxon.find_by_id(to_merge_ids.first)
      puts "lt: #{lt}, merging #{to_merge_ids}" if debug
      rejects = ListedTaxon.where(id: to_merge_ids[1..-1])

      # remove the rejects from the list before merging to avoid alread-on-list validation errors
      ListedTaxon.where(id: rejects).update_all(list_id: nil)
      
      rejects.each do |reject|
        begin
          lt.merge( reject )
        rescue ActiveRecord::RecordInvalid
          puts "Validation error on #{reject}, skipping merge and deleting" if debug
          reject.destroy
        end
      end
    end
  end

  def self.update_for_taxon_change(taxon_change, options = {})
    input_taxon_ids = taxon_change.input_taxa.map(&:id)
    scope = ListedTaxon.where("listed_taxa.taxon_id IN (?)", input_taxon_ids)
    scope = scope.where(:user_id => options[:user]) if options[:user]
    scope = scope.where("listed_taxa.id IN (?)", options[:records]) unless options[:records].blank?
    scope = scope.where(options[:conditions]) if options[:conditions]
    scope = scope.includes(options[:include]) if options[:include]
    scope.find_each do |lt|
      lt.force_update_cache_columns = true
      if output_taxon = taxon_change.output_taxon_for_record( lt )
        next if !taxon_change.automatable_for_output?( output_taxon.id )
        if existing = ListedTaxon.where( list_id: lt.list_id, taxon_id: output_taxon.id ).first
          existing.skip_index_taxon = true
          begin
            existing.merge( lt )
          rescue ActiveRecord::RecordInvalid => e
            Rails.logger.error "Failed to update #{lt} for #{taxon_change}: #{e.message}"
          end
        else
          lt.skip_index_taxon = true
          lt.update_attributes( taxon: output_taxon )
        end
      end
      yield(lt) if block_given?
    end
  end

  def related_listed_taxa
    ListedTaxon.where(taxon_id: taxon_id, place_id: place_id).where("id != ?", id)
  end

  def other_primary_listed_taxa?
    scope = ListedTaxon.where(taxon_id:taxon_id, place_id: place_id, primary_listing: true)
    scope = scope.where("id != ?", id) if id
    scope.count > 0
  end
  
  def multiple_primary_listed_taxa?
    scope = ListedTaxon.where(taxon_id:taxon_id, place_id: place_id, primary_listing: true)
    scope = scope.where("id != ?", id) if id
    scope.count > 1
  end
  
  def primary_listed_taxon
    primary_listing ? self : ListedTaxon.where(taxon_id:taxon_id, place_id: place_id, primary_listing: true).first
  end

  def check_primary_listing
    self.primary_listing = !other_primary_listed_taxa? && can_set_as_primary?
    true
  end

  def can_set_as_primary?
    list && list.is_a?(CheckList)
  end
  
  def remove_other_primary_listings
    return true unless primary_listing && multiple_primary_listed_taxa?
    ListedTaxon.where("taxon_id = ? AND place_id = ? AND id != ?",
      taxon_id, place_id, id).update_all(primary_listing: false)
    true
  end
  
  def reassign_primary_listed_taxon
    return unless primary_listing
    related_listed_taxon = related_listed_taxa.first
    related_listed_taxon.update_attribute(:primary_listing, true) if related_listed_taxon && related_listed_taxon.list_id && related_listed_taxon.place_id && can_set_as_primary?
  end

  def update_attributes_on_related_listed_taxa
    return true unless primary_listing
    related_listed_taxa.each do |related_listed_taxon|
      related_listed_taxon.primary_listing = false
      related_listed_taxon.establishment_means = establishment_means
      related_listed_taxon.first_observation_id = first_observation_id
      related_listed_taxon.last_observation_id = last_observation_id 
      related_listed_taxon.observations_count = observations_count
      related_listed_taxon.occurrence_status_level = occurrence_status_level
      related_listed_taxon.skip_index_taxon = true
      related_listed_taxon.skip_update_cache_columns = true
      related_listed_taxon.save
    end
    true
  end

  def make_primary_if_no_primary_exists
    update_attribute(:primary_listing, true) if !ListedTaxon.where({taxon_id:taxon_id, place_id: place_id, primary_listing: true}).present? && can_set_as_primary?
  end
  
  # used with threatened_status filter
  def self.place_ancestor_ids_sql(place_ids)
    place_ids = [ place_ids ] unless place_ids.is_a?(Array)
    <<-SQL
      SELECT DISTINCT 
        regexp_split_to_table(ancestry, '/') AS ancestor_id 
      FROM places
      WHERE
        id IN (#{ place_ids.join(",") }) AND
        ancestry IS NOT NULL
    SQL
  end
  
  def primary_occurrence_status
    primary_listed_taxon.try(:occurrence_status)
  end

  def primary_establishment_means
    primary_listed_taxon.try(:establishment_means)
  end

  def update_attributes_and_primary(listed_taxon, current_user)
    transaction do
      update_attributes(listed_taxon.merge(:updater_id => current_user.id))
      if primary_listed_taxon && primary_listed_taxon != self
        primary_listed_taxon.update_attributes(
          occurrence_status_level: listed_taxon['occurrence_status_level'],
          establishment_means: listed_taxon['establishment_means']
        )
      end
    end
  end

  def as_indexed_json
    {
      id: id,
      place_id: place_id,
      user_id: user_id,
      occurrence_status_level: occurrence_status_level,
      establishment_means: establishment_means
    }
  end

  def establishment_means_label
    I18n.t( "establishment.#{establishment_means}", default: establishment_means ).capitalize
  end

  def establishment_means_description
    default = ListedTaxon::ESTABLISHMENT_MEANS_DESCRIPTIONS[establishment_means]
    key = default.gsub( "-", "_" ).gsub( " ", "_" ).downcase
    I18n.t( "establishment_means_descriptions.#{ key }", default: default )
  end

  def reindex_observations_later
    return true if taxon_id.blank? || place_id.blank?
    return true unless previous_changes[:establishment_means]
    ListedTaxon.delay(
      priority: INTEGRITY_PRIORITY,
      unique_hash: {
        "CheckList::reindex_observations_later.taxon_id": taxon_id,
        "CheckList::reindex_observations_later.place_id": place_id,
      }
    ).reindex_observations( taxon_id, place_id )
    true
  end

  def self.reindex_observations( taxon_id, place_id )
    last_id = 0
    per_page = 1000
    while true
      res = Observation.elastic_search(
        source: ["id"],
        sort: { id: "asc" },
        filters: [
          { range: { id: { gt: last_id } } },
          { term: { private_place_ids: place_id } },
          { term: { "taxon.ancestor_ids": taxon_id } }
        ]
      ).per_page( per_page )
      ids = res.response.hits.hits.map(&:_id).map(&:to_i)
      break if ids.blank?
      Observation.elastic_index!( delay: true, ids: ids )
      last_id += ids.last
    end
  end

end
