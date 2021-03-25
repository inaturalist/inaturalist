#encoding: utf-8
class Taxon < ActiveRecord::Base
  # Sometimes you don't want to make a new taxon name with a taxon, like when
  # you're saving a new taxon name with a new associated taxon. Hence, this.
  attr_accessor :skip_new_taxon_name
  
  # If you want to shove some HTML in there before creating some JSON...
  attr_accessor :html
  
  # Allow this taxon to be grafted to locked subtrees
  attr_accessor :skip_locks
  
  # Allow this taxon to be grafted to curated subtrees
  attr_accessor :skip_taxon_framework_checks
  
  # Allow this taxon to be inactivated despite having active children
  attr_accessor :skip_only_inactive_children_if_inactive

  # Skip the more onerous callbacks that happen after grafting a taxon somewhere else
  attr_accessor :skip_after_move

  attr_accessor :locale

  # set this when you want methods to respond with user-specific content
  attr_accessor :current_user
  attr_accessor :skip_observation_indexing

  include ActsAsElasticModel
  # include ActsAsUUIDable
  before_validation :set_uuid
  def set_uuid
    self.uuid ||= SecureRandom.uuid
    self.uuid = uuid.downcase
    true
  end
  acts_as_flaggable
  has_ancestry orphan_strategy: :adopt

  has_many :taxon_names, :dependent => :destroy
  has_many :taxon_changes
  has_many :taxon_change_taxa, inverse_of: :taxon
  has_many :observations, :dependent => :nullify
  has_many :listed_taxa, :dependent => :destroy
  has_many :listed_taxa_with_establishment_means,
    -> { where("establishment_means IS NOT NULL") },
    class_name: "ListedTaxon"
  has_many :listed_taxa_with_means_or_statuses,
    -> { where("establishment_means IS NOT NULL OR occurrence_status_level IS NOT NULL") },
    class_name: "ListedTaxon"
  has_many :taxon_scheme_taxa, :dependent => :destroy
  has_many :taxon_schemes, :through => :taxon_scheme_taxa
  has_many :lists, :through => :listed_taxa
  has_many :places,
    -> { where( "listed_taxa.occurrence_status_level IS NULL OR listed_taxa.occurrence_status_level IN (?)", ListedTaxon::PRESENT_EQUIVALENTS ) },
    through: :listed_taxa
  has_many :identifications, :dependent => :destroy
  has_many :taxon_links, :dependent => :delete_all 
  has_many :taxon_ranges, :dependent => :destroy
  has_many :taxon_ranges_without_geom, -> { select(TaxonRange.column_names - ['geom']) }, :class_name => 'TaxonRange'
  has_many :taxon_photos, -> { order("position ASC NULLS LAST, id ASC") }, :dependent => :destroy
  has_many :photos, :through => :taxon_photos
  has_many :assessments, :dependent => :nullify
  has_many :conservation_statuses, :dependent => :destroy
  has_many :guide_taxa, :inverse_of => :taxon, :dependent => :nullify
  has_many :guides, :inverse_of => :taxon, :dependent => :nullify
  has_many :taxon_ancestors, :dependent => :delete_all
  has_many :taxon_ancestors_as_ancestor, :class_name => "TaxonAncestor", :foreign_key => :ancestor_taxon_id, :dependent => :delete_all
  has_many :ancestor_taxa, :class_name => "Taxon", :through => :taxon_ancestors
  has_one :atlas, inverse_of: :taxon, dependent: :destroy
  has_one :taxon_framework, inverse_of: :taxon, dependent: :destroy
  has_many :listed_taxon_alterations, inverse_of: :taxon, dependent: :delete_all
  has_many :observation_field_values,
    -> { joins(:observation_field).where( "observation_fields.datatype = ?", ObservationField::TAXON ) },
    foreign_key: :value
  belongs_to :source
  belongs_to :iconic_taxon, :class_name => 'Taxon', :foreign_key => 'iconic_taxon_id'
  belongs_to :creator, :class_name => 'User'
  has_updater
  belongs_to :conservation_status_source, :class_name => "Source"
  belongs_to :taxon_framework_relationship, touch: true
  has_and_belongs_to_many :colors, -> { uniq }
  has_many :taxon_descriptions, :dependent => :destroy
  has_one :en_wikipedia_description,
    -> { where("locale='en' AND provider='Wikipedia'") },
    class_name: "TaxonDescription"
  has_many :controlled_term_taxa, inverse_of: :taxon, dependent: :destroy
  has_many :taxon_curators, inverse_of: :taxon  # deprecated, remove when we're sure transition to taxon frameworks is complete
  has_one :simplified_tree_milestone_taxon, dependent: :destroy

  accepts_nested_attributes_for :conservation_status_source
  accepts_nested_attributes_for :source
  accepts_nested_attributes_for :conservation_statuses, :reject_if => :all_blank, :allow_destroy => true
  accepts_nested_attributes_for :taxon_photos, :allow_destroy => true

  before_validation :normalize_rank, :set_rank_level, :remove_rank_from_name
  before_save :set_iconic_taxon, # if after, it would require an extra save
              :strip_name,
              :capitalize_name,
              :remove_wikipedia_summary_unless_auto_description,
              :ensure_parent_ancestry_in_ancestry,
              :unfeature_inactive
  after_create :denormalize_ancestry
  after_save :create_matching_taxon_name,
             :set_wikipedia_summary_later,
             :reindex_identifications_after_save,
             :handle_after_move,
             :handle_after_activate,
             :update_taxon_framework_relationship
  after_destroy :update_taxon_framework_relationship
  after_save :index_observations

  validates_presence_of :name, :rank, :rank_level
  validates_uniqueness_of :name, 
                          :scope => [:ancestry, :is_active],
                          :unless => Proc.new { |taxon| (taxon.ancestry.blank? || !taxon.is_active)},
                          :message => "already used as a child of this taxon's parent"
  # validates_uniqueness_of :source_identifier,
  #                         :scope => [:source_id],
  #                         :message => "already exists",
  #                         :allow_blank => true
  validates :name, format: { with: TaxonName::NAME_FORMAT, message: :bad_format }, on: :create
  validate :taxon_cant_be_its_own_ancestor
  validate :can_only_be_featured_if_photos
  validate :validate_locked
  validate :graftable_relative_to_taxon_framework_coverage
  validate :user_can_edit_attributes, on: :update
  validate :graftable_destination_relative_to_taxon_framework_coverage
  validate :rank_level_must_be_coarser_than_children
  validate :rank_level_must_be_finer_than_parent
  validate :rank_level_for_taxon_and_parent_must_not_be_nil
  validate :only_inactive_children_if_inactive
  validate :active_parent_if_active
  validate :has_ancestry_and_active_if_taxon_framework
  validate :cannot_edit_parent_during_content_freeze

  has_subscribers :to => {
    :observations => {:notification => "new_observations", :include_owner => false}
  }
  
  NAME_PROVIDER_TITLES = {
    'ColNameProvider' => 'Catalogue of Life',
    'NZORNameProvider' => 'New Zealand Organisms Register',
    'UBioNameProvider' => 'uBio'
  }
  
  RANK_LEVELS = {
    "stateofmatter"   => 100,
    "kingdom"         => 70,
    "phylum"          => 60,
    "subphylum"       => 57,
    "superclass"      => 53,
    "class"           => 50,
    "subclass"        => 47,
    "infraclass"      => 45,
    "subterclass"     => 44,
    "superorder"      => 43,
    "order"           => 40,
    "suborder"        => 37,
    "infraorder"      => 35,
    "parvorder"       => 34.5,
    "zoosection"      => 34,
    "zoosubsection"   => 33.5,
    "superfamily"     => 33,
    "epifamily"       => 32,
    "family"          => 30,
    "subfamily"       => 27,
    "supertribe"      => 26,
    "tribe"           => 25,
    "subtribe"        => 24,
    "genus"           => 20,
    "genushybrid"     => 20,
    "subgenus"        => 15,
    "section"         => 13,
    "subsection"      => 12,
    "complex"         => 11,
    "species"         => 10,
    "hybrid"          => 10,
    "subspecies"      => 5,
    "variety"         => 5,
    "form"            => 5,
    "infrahybrid"     => 5
  }
  RANK_LEVELS.each do |rank, level|
    const_set rank.upcase, rank
    const_set "#{rank.upcase}_LEVEL", level
    define_method "find_#{rank}" do
      return self if self.rank == rank
      return nil if rank_level.to_i > level.to_i
      @cached_ancestors ||= ancestor_taxa.loaded? ? ancestor_taxa :
        ancestors.select("id, name, rank, ancestry,
          iconic_taxon_id, rank_level, created_at, updated_at, is_active,
          observations_count").all
      @cached_ancestors.detect{|a| a.rank == rank}
    end
    alias_method(rank, "find_#{rank}") unless respond_to?(rank)
    define_method "taxonomic_#{rank}_name" do
      send("find_#{rank}").try(:name)
    end
    alias_method("#{rank}_name", "taxonomic_#{rank}_name") unless respond_to?("#{rank}_name")
    define_method "#{rank}?" do
      self.rank == rank
    end
  end
  ROOT_LEVEL = STATEOFMATTER_LEVEL
  
  RANK_FOR_RANK_LEVEL = RANK_LEVELS.select{|k,v| !["variety","form","infrahybrid","hybrid","genushybrid"].include? k}.invert
  
  RANKS = RANK_LEVELS.keys
  VISIBLE_RANKS = RANKS - ['stateofmatter']
  
  RANK_EQUIVALENTS = {
    'division'        => 'phylum',
    'sub-class'       => 'subclass',
    'super-order'     => 'superorder',
    'sub-order'       => 'suborder',
    'super-family'    => 'superfamily',
    'sub-family'      => 'subfamily',
    'gen'             => 'genus',
    'sp'              => 'species',
    'spp'             => 'species',
    'infraspecies'    => 'subspecies',
    'ssp'             => 'subspecies',
    'sub-species'     => 'subspecies',
    'subsp'           => 'subspecies',
    'trinomial'       => 'subspecies',
    'var'             => 'variety',
    'unranked'        => nil
  }
  
  PREFERRED_RANKS = [
    'kingdom',
    'phylum',
    'class',
    'order',
    'superfamily',
    'family',
    'genus',
    'species',
    'subspecies',
    'variety'
  ]

  WIKIPEDIA_RANKS = {
    "infratribe" => "infratribus",
    "infraphylum" => "infraphylum",
    "infraorder" => "infraordo",
    "cohort" => "cohort",
    "microrder" => "micrordo",
    "genus" => "genus",
    "subsection" => "zoosubsectio",
    "grandorder" => "grandordo",
    "microphylum" => "microphylum",
    "sublegion" => "sublegio",
    "subdivision" => "zoosubdivisio",
    "parvclass" => "parvclassis",
    "supercohort" => "supercohort",
    "nanorder" => "nanordo",
    "parafamily" => "parafamilia",
    "superdivision" => "superdivisio",
    "superlegion" => "superlegio",
    "magnorder" => "magnordo",
    "variety" => "varietas",
    "tribe" => "tribus",
    "parvorder" => "parvordo",
    "superfamily" => "superfamilia",
    "subphylum" => "subphylum",
    "superphylum" => "superphylum",
    "infrakingdom" => "infraregnum",
    "mb" => "grandordo",
    "supertribe" => "supertribus",
    "division" => "zoodivisio",
    "hyperfamily" => "hyperfamilia",
    "section" => "zoosectio",
    "superclass" => "superclassis",
    "subtribe" => "subtribus",
    "subterclass" => "subterclassis",
    "division" => "divisio",
    "subspecies" => "subspecies",
    "class" => "classis",
    "subsection" => "subsectio",
    "infraclass" => "infraclassis",
    "subcohort" => "subcohort",
    "subfamily" => "subfamilia",
    "subkingdom" => "subregnum",
    "superkingdom" => "superregnum",
    "species" => "species",
    "suborder" => "subordo",
    "subgenus" => "subgenus",
    "subdivision" => "subdivisio",
    "order" => "ordo",
    "subclass" => "subclassis",
    "section" => "sectio",
    "legion" => "legio",
    "kingdom" => "regnum",
    "domain" => "domain",
    "superdomain" => "superdomain",
    "superorder" => "superordo",
    "nanophylum" => "nanophylum",
    "family" => "familia",
    "mirordo" => "mirordo-mb",
    "infralegion" => "infralegio",
    "form" => "forma",
    "mirorder" => "mirordo",
    "phylum" => "phylum"
  }
  
  # In case you don't feel like looking up TaxonNames
  ICONIC_TAXON_NAMES = {
    'Animalia' => 'Animals',
    'Actinopterygii' => 'Ray-finned Fishes',
    'Aves' => 'Birds',
    'Reptilia' => 'Reptiles',
    'Amphibia' => 'Amphibians',
    'Mammalia' => 'Mammals',
    'Arachnida' => 'Arachnids',
    'Insecta' => 'Insects',
    'Plantae' => 'Plants',
    'Fungi' => 'Fungi',
    'Protozoa' => 'Protozoans',
    'Mollusca' => 'Mollusks',
    'Chromista' => 'Chromista'
  }
  
  ICONIC_TAXON_DISPLAY_NAMES = ICONIC_TAXON_NAMES.merge(
    'Animalia' => 'Other Animals'
  )
  
  LIFE = Taxon.roots.find_by_name('Life')
  
  IUCN_NOT_EVALUATED = 0
  IUCN_DATA_DEFICIENT = 5
  IUCN_LEAST_CONCERN = 10
  IUCN_NEAR_THREATENED = 20
  IUCN_VULNERABLE = 30
  IUCN_ENDANGERED = 40
  IUCN_CRITICALLY_ENDANGERED = 50
  IUCN_EXTINCT_IN_THE_WILD = 60
  IUCN_EXTINCT = 70
  IUCN_STATUS_NAMES = %w(not_evaluated data_deficient least_concern
    near_threatened vulnerable endangered critically_endangered
    extinct_in_the_wild extinct)
  IUCN_STATUS_CODES = {
    "not_evaluated"         => "NE",
    "data_deficient"        => "DD",
    "least_concern"         => "LC",
    "near_threatened"       => "NT",
    "vulnerable"            => "VU",
    "endangered"            => "EN",
    "critically_endangered" => "CR",
    "extinct_in_the_wild"   => "EW",
    "extinct"               => "EX"
  }
  IUCN_STATUSES = Hash[IUCN_STATUS_NAMES.map {|status_name|
    [const_get("IUCN_#{status_name.upcase}"), status_name]
  }]
  IUCN_STATUSES_SELECT = IUCN_STATUS_NAMES.map do |status_name|
    ["#{I18n.t(status_name, :default => status_name).humanize} (#{IUCN_STATUS_CODES[status_name]})", const_get("IUCN_#{status_name.upcase}")]
  end
  IUCN_STATUS_VALUES = Hash[IUCN_STATUS_NAMES.map {|status_name|
    [status_name, const_get("IUCN_#{status_name.upcase}")]
  }]
  IUCN_STATUS_NAMES.each do |status_name|
    define_method("iucn_#{status_name}?") do
      conservation_status == self.class.const_get("IUCN_#{status_name.upcase}")
    end
  end
  IUCN_CODE_VALUES = Hash[IUCN_STATUS_VALUES.map{|name,value|
    [IUCN_STATUS_CODES[name], value]
  }]
  
  # Names we don't use when trying to extract a taxon from text because they
  # usually map to the wrong thing. Also including all place names for
  # state-level places and above that are also taoxn names, since they often get
  # used in photo tags
  abbr_date_names = I18N_SUPPORTED_LOCALES.map{|locale|
    [
      I18n.t( "date.abbr_month_names", locale: locale ),
      I18n.t( "date.abbr_day_names", locale: locale )
    ]
  }.flatten.select{|n| !n.blank? && n.to_f == 0}.map{|n| n.to_s.downcase }.uniq
  place_names_that_are_taxon_names = Taxon.select( "DISTINCT taxa.name" ).
    joins( "JOIN places ON places.name = taxa.name" ).
    where( "places.admin_level < 2" ).
    pluck(:name).uniq.sort.map(&:downcase)
  PROBLEM_NAMES = [
    "aba",
    "america",
    "asa",
    "bee hive",
    "canon",
    "caterpillar",
    "caterpillars",
    "chiton",
    "cicada",
    "creeper",
    "eos",
    "gall",
    "hong kong",
    "larva",
    "lichen",
    "lizard",
    "pinecone",
    "pupa",
    "pupae",
    "sea",
    "winged insect"
  ] + place_names_that_are_taxon_names + abbr_date_names
  
  PROTECTED_ATTRIBUTES_FOR_CURATED_TAXA = %w(
    ancestry
    is_active
    rank
    rank_level
  )

  scope :observed_by, lambda {|user|
    sql = <<-SQL
      JOIN (
        SELECT
          taxon_id
        FROM
          observations
        WHERE
          user_id=#{user.id}
        GROUP BY taxon_id
      ) o
      ON o.taxon_id=#{Taxon.table_name}.#{Taxon.primary_key}
    SQL
    joins(sql)
  }
  
  scope :iconic_taxa, -> { where("taxa.is_iconic = true").includes(:taxon_names) }
  scope :of_rank, lambda {|rank| where("taxa.rank = ?", rank)}
  scope :of_rank_equiv, lambda {|rank_level| where("taxa.rank_level = ?", rank_level)}
  scope :of_rank_equiv_or_lower, lambda {|rank_level| where("taxa.rank_level <= ?", rank_level)}
  scope :is_locked, -> { where(:locked => true) }
  scope :containing_lat_lng, lambda {|lat, lng|
    joins(:taxon_ranges).where("ST_Intersects(taxon_ranges.geom, ST_Point(?, ?))", lng, lat)
  }
  
  # Like it's counterpart in Place, this is potentially VERY expensive/slow
  scope :intersecting_place, lambda {|place|
    place_id = place.is_a?(Place) ? place.id : place.to_i
    joins("JOIN place_geometries ON place_geometries.place_id = #{place_id}").
    joins("JOIN taxon_ranges ON taxon_ranges.taxon_id = taxa.id").
    where("ST_Intersects(place_geometries.geom, taxon_ranges.geom)")
  }
  
  # this is potentially VERY expensive/slow
  scope :contained_in_place, lambda {|place|
    place_id = place.is_a?(Place) ? place.id : place.to_i
    joins("JOIN place_geometries ON place_geometries.place_id = #{place_id}").
    joins("JOIN taxon_ranges ON taxon_ranges.taxon_id = taxa.id").
    where("ST_Contains(place_geometries.geom, taxon_ranges.geom)")
  }

  scope :observed_in_place, lambda {|place|
    place_id = place.is_a?(Place) ? place.id : place.to_i 
    joins(:observations).
    joins("JOIN place_geometries ON place_geometries.place_id = #{place_id}").
    where("ST_Contains(place_geometries.geom, observations.geom)").
    select("DISTINCT ON (taxa.id) taxa.*")
  }
  
  scope :has_photos, -> { joins(:taxon_photos).where("taxon_photos.id IS NOT NULL") }
  scope :among, lambda {|ids| where("taxa.id IN (?)", ids)}
  
  scope :self_and_descendants_of, lambda{|taxon|
    if taxon
      conditions = taxon.descendant_conditions.to_sql
      conditions += " OR taxa.id = #{ taxon.id }"
      where(conditions)
    else
      where("1 = 2")
    end
  }
  
  scope :has_conservation_status, lambda {|status|
    if status.is_a?(String)
      status = if status.size == 2
        IUCN_STATUS_VALUES[IUCN_STATUS_CODES.invert[status]]
      else
        IUCN_STATUS_VALUES[status]
      end
    end
    where("conservation_status = ?", status.to_i)
  }
  scope :has_conservation_status_in_place, lambda {|status, place|
    if status.is_a?(String)
      status = if status.size == 2
        IUCN_STATUS_VALUES[IUCN_STATUS_CODES.invert[status]]
      else
        IUCN_STATUS_VALUES[status]
      end
    end
    joins(:conservation_statuses).
    where("conservation_statuses.iucn = ?", status.to_i).
    where("(conservation_statuses.place_id = ? OR conservation_statuses.place_id IS NULL)", place)
  }
    
  scope :threatened, -> { where("conservation_status >= ?", IUCN_NEAR_THREATENED) }
  scope :threatened_in_place, lambda {|place|
    joins(:conservation_statuses).
    where("conservation_statuses.iucn >= ?", IUCN_NEAR_THREATENED).
    where("(conservation_statuses.place_id::text IN (#{ListedTaxon.place_ancestor_ids_sql(place.id)}) OR conservation_statuses.place_id IS NULL)")
  }
  
  scope :from_place, lambda {|place|
    joins(:listed_taxa).where("listed_taxa.place_id = ?", place)
  }
  scope :on_list, lambda {|list|
    joins(:listed_taxa).where("listed_taxa.list_id = ?", list)
  }
  scope :active, -> { where(:is_active => true) }
  scope :inactive, -> { where(:is_active => false) }
  
  ICONIC_TAXA = Taxon.sort_by_ancestry(self.iconic_taxa.arrange)
  ICONIC_TAXA_BY_ID = ICONIC_TAXA.index_by(&:id)
  ICONIC_TAXA_BY_NAME = ICONIC_TAXA.index_by(&:name)

  def self.reset_iconic_taxa_constants_for_tests
    remove_const('ICONIC_TAXA')
    remove_const('ICONIC_TAXA_BY_ID')
    remove_const('ICONIC_TAXA_BY_NAME')
    const_set('ICONIC_TAXA', Taxon.sort_by_ancestry(self.iconic_taxa.arrange))
    const_set('ICONIC_TAXA_BY_ID', Taxon::ICONIC_TAXA.index_by(&:id))
    const_set('ICONIC_TAXA_BY_NAME', Taxon::ICONIC_TAXA.index_by(&:name))
  end

  # Callbacks ###############################################################

  def cannot_edit_parent_during_content_freeze
    return unless CONFIG.content_freeze_enabled
    return if new_record?
    return unless ancestry_changed?
    errors.add( :parent_id, I18n.t( "cannot_be_changed_during_a_content_freeze" ) )
  end

  def reindex_identifications_after_save
    return if new_record?
    reindex_needed = %w(rank rank_level iconic_taxon_id ancestry).detect do |a|
      send("#{a}_changed?")
    end
    if reindex_needed
      Identification.delay(
        priority: INTEGRITY_PRIORITY,
        queue: "slow",
        unique_hash: { "Identification::reindex_for_taxon": id }
      ).reindex_for_taxon( id )
    end
  end

  def handle_after_move
    return true unless ancestry_changed?
    set_iconic_taxon
    return true if skip_after_move
    denormalize_ancestry
    return true if id_changed?
    update_obs_iconic_taxa
    Observation.delay(priority: INTEGRITY_PRIORITY, queue: "slow",
      unique_hash: { "Observation::update_stats_for_observations_of": id }).
      update_stats_for_observations_of(id)
    elastic_index!
    Taxon.refresh_es_index
    # This will create a long-running job for higher level, but we need to reset
    # the ancestry field on descendants when the taxon moves
    Taxon.delay(
      priority: INTEGRITY_PRIORITY,
      queue: "slow",
      unique_hash: { "Taxon::reindex_descendants_of": id }
    ).reindex_descendants_of( id )
    Identification.delay( priority: INTEGRITY_PRIORITY, queue: "slow",
      unique_hash: { "Identification::update_disagreement_identifications_for_taxon": id }).
      update_disagreement_identifications_for_taxon(id)
    annotation_taxon_ids_to_reassess = [ancestry_was.to_s.split( "/" ).map(&:to_i), id].flatten.compact.sort
    annotation_taxon_ids_to_reassess.each do |taxon_id|
      next if Taxon::LIFE && taxon_id == Taxon::LIFE.id
      Annotation.delay( priority: INTEGRITY_PRIORITY, queue: "slow",
        run_at: 1.day.from_now,
        unique_hash: { "Annotation::reassess_annotations_for_taxon_ids": [taxon_id] } ).
        reassess_annotations_for_taxon_ids( [taxon_id] )
    end
    if has_taxon_framework_relationship
      reasess_taxon_framework_relationship_after_move
    end
    true
  end

  def handle_after_activate
    return true unless is_active_changed?
    Observation.delay( priority: INTEGRITY_PRIORITY, queue: "slow",
      unique_hash: { "Observation::update_stats_for_observations_of": id } ).
      update_stats_for_observations_of( id )
    true
  end

  def self.get_internal_taxa_covered_by( taxon_framework )
    ancestry_string = ( taxon_framework.taxon.rank == STATEOFMATTER || taxon_framework.taxon.ancestry.nil? ) ?
      "#{ taxon_framework.taxon_id }" : "#{ taxon_framework.taxon.ancestry }/#{ taxon_framework.taxon.id }"
    other_taxon_frameworks = TaxonFramework.joins(:taxon).
      where( "( taxa.ancestry LIKE ( '#{ ancestry_string }/%' ) OR taxa.ancestry LIKE ( '#{ ancestry_string }' ) )" ).
      where( "taxa.rank_level > #{ taxon_framework.rank_level } AND taxon_frameworks.rank_level IS NOT NULL" )
    other_taxon_frameworks_taxa = ( other_taxon_frameworks.count > 0 ) ?
      Taxon.where(id: other_taxon_frameworks.map(&:taxon_id)) : []
    
    internal_taxa = Taxon.where( "ancestry = ? OR ancestry LIKE ?", ancestry_string, "#{ancestry_string}/%" ).
      where( is_active: true ).
      where( "rank_level >= ? ", taxon_framework.rank_level).
      where("( select count(*) from conservation_statuses ct where ct.taxon_id=taxa.id AND ct.iucn=70 AND ct.place_id IS NULL ) = 0")

    other_taxon_frameworks_taxa.each do |t|
      internal_taxa = internal_taxa.where("ancestry != ? AND ancestry NOT LIKE ?", "#{t.ancestry}/#{t.id}", "#{t.ancestry}/#{t.id}/%")
    end

    return internal_taxa
  end
  
  def self.reindex_taxa_covered_by( taxon_framework )
    Taxon.elastic_index!( scope: Taxon.get_internal_taxa_covered_by(taxon_framework) )
  end

  def self.reindex_descendants_of( taxon )
    taxon = Taxon.find_by_id( taxon ) unless taxon.is_a?( Taxon )
    return unless taxon
    Taxon.elastic_index!( scope: taxon.descendants )
  end
  
  def update_taxon_framework_relationship
    return true unless self.taxon_framework_relationship
    taxon_framework_relationship.set_relationship if (destroyed? || name_changed? || rank_changed? || ancestry_changed? || taxon_framework_relationship_id_changed?)
    attrs = {}
    attrs[:relationship] = taxon_framework_relationship.relationship
    taxon_framework_relationship.update_attributes(attrs)
  end
    
  def complete_species_count
    return nil if rank_level.to_i <= SPECIES_LEVEL
    unless ( taxon_framework && taxon_framework.covers? && taxon_framework.complete && taxon_framework.rank_level <= SPECIES_LEVEL )
      upstream_framework = upstream_taxon_framework
      return nil unless ( upstream_framework && upstream_framework.complete && upstream_framework.rank_level <= SPECIES_LEVEL )
    end
    scope = taxon_ancestors_as_ancestor.
      select("distinct taxon_ancestors.taxon_id").
      joins(:taxon).
      where( "taxon_ancestors.taxon_id != ? AND rank = ? AND is_active", id, SPECIES ).
      where( "(select count(*) from conservation_statuses cs
        WHERE cs.taxon_id = taxa.id AND cs.place_id IS NULL AND cs.iucn = ?) = 0", Taxon::IUCN_EXTINCT )
    scope.count
  end

  def denormalize_ancestry
    Taxon.transaction do
      TaxonAncestor.where( taxon_id: id ).delete_all
      unless self_and_ancestor_ids.blank?
        sql = "INSERT INTO taxon_ancestors VALUES " + self_and_ancestor_ids.map {|aid| "(#{id},#{aid})" }.join( "," )
        ActiveRecord::Base.connection.execute( sql )
      end
    end
  end

  def index_observations
    return if skip_observation_indexing
    # changing some fields doesn't require reindexing observations
    return if ( changes.keys - [
      "photos_locked",
      "taxon_framework_relationship_id",
      "updater_id",
      "updated_at"
    ] ).empty?
    Observation.elastic_index!( scope: observations.select( :id ), delay: true )
  end

  def normalize_rank
    self.rank = Taxon.normalize_rank(self.rank)
    true
  end
  
  def set_rank_level
    self.rank_level = RANK_LEVELS[self.rank]
    true
  end
  
  def remove_rank_from_name
    self.name = Taxon.remove_rank_from_name(self.name)
    true
  end
  
  #
  # Set the iconic taxon if it hasn't been set
  #
  def set_iconic_taxon(options = {})
    unless iconic_taxon_id_changed?
      self.iconic_taxon = if is_iconic?
        self
      else
        ancestors.reverse.select {|a| a.is_iconic?}.first
      end
    end
    
    if !new_record? && (iconic_taxon_id_changed? || options[:force])
      new_child_ancestry = "#{ancestry}/#{id}"
      conditions = ["(ancestry LIKE ? OR ancestry = ?)", "#{new_child_ancestry}/%", new_child_ancestry]
      conditions[0] += " AND (iconic_taxon_id IN (?) OR iconic_taxon_id IS NULL)"
      conditions << ancestry_was.to_s.split('/')
      Taxon.where(conditions).update_all(iconic_taxon_id: iconic_taxon_id)
      Taxon.delay(:priority => USER_INTEGRITY_PRIORITY).set_iconic_taxon_for_observations_of(id)
    end
    true
  end
  
  def set_wikipedia_summary_later
    delay(:priority => OPTIONAL_PRIORITY).set_wikipedia_summary if wikipedia_title_changed?
    true
  end

  def self.set_conservation_status(id)
    return unless t = Taxon.find_by_id(id)
    s = t.conservation_statuses.where("place_id IS NULL").pluck(:iucn).max
    Taxon.where(id: t).update_all(conservation_status: s)
  end
  
  def capitalize_name
    self.name = Taxon.capitalize_scientific_name( name, rank )
    true
  end

  def self.capitalize_scientific_name( name, rank )
    if rank.blank?
      name.capitalize
    elsif [GENUS, GENUSHYBRID].include?( rank ) && name =~ /^(x|×)\s+?(.+)/
      full_name, x, genus_name = name.match(/^(x|×)\s+?(.+)/).to_a
      "#{x} #{genus_name.capitalize}"
    elsif [GENUS, GENUSHYBRID].include?( rank ) && name =~ /^\w+\s+(x|×)\s+\w+$/
      full_name, name1, x, name2 = name.match( /^(\w+)\s+(x|×)\s+(\w+)/ ).to_a
      "#{name1.capitalize} #{x} #{name2.capitalize}"
    elsif rank == HYBRID && name =~ /(x|×)\s+\w+\s+\w+/
      full_name, name1, x, name2 = name.match( /^(.+)\s+(x|×)\s+(.+)/ ).to_a
      if name1 && name2
        "#{name1.capitalize} #{x} #{name2.capitalize}"
      else
        name.capitalize
      end
    else
      name.capitalize
    end
  end

  def strip_name
    self.name = name.strip
    true
  end
  
  # Create a taxon name with the same name as this taxon
  def create_matching_taxon_name
    return true if @skip_new_taxon_name
    return true if scientific_name
    
    taxon_attributes = self.attributes
    taxon_attributes.delete('id')
    tn = TaxonName.new
    taxon_attributes.each do |k,v|
      tn[k] = v if TaxonName.column_names.include?(k)
    end
    tn.lexicon = TaxonName::LEXICONS[:SCIENTIFIC_NAMES]
    tn.is_valid = true

    if !tn.valid? && !tn.errors[:source_identifier].blank?
      tn.source_identifier = nil
    end
    
    self.taxon_names << tn
    true
  end
  
  def self.update_ancestor_photos(taxon, photo)
    taxon = Taxon.find_by_id( taxon ) unless taxon.is_a?( Taxon )
    return unless taxon
    photo = Photo.find_by_id( photo ) unless photo.is_a?( Photo )
    return unless photo
    taxon.ancestors.each do |anc|
      unless anc.photos.count > 0
        anc.photos << photo
      end
    end
  end
  
  # /Callbacks ##############################################################
  
  
  # see the end for the validate method
  def to_s
    "<Taxon #{id}: #{to_plain_s(:skip_common => true)}>"
  end
  
  def to_param
    return nil if new_record?
    "#{id}-#{name.gsub(/\W/, '-')}"
  end
  
  def to_plain_s(options = {})
    comname = common_name unless options[:skip_common]
    sciname = if %w(species infraspecies).include?(rank) || rank.blank?
      name
    else
      "#{rank.capitalize} #{name}"
    end
    return sciname if comname.blank?
    "#{comname.name} (#{sciname})"
  end
  
  def to_styled_s(options = {})
    comname = common_name unless options[:skip_common]
    sciname = %w(genus species infraspecies).include?(rank) ? "<i>#{name}</i>" : name
    unless %w(species infraspecies).include?(rank) || rank.blank?
      sciname = rank.capitalize + " " + sciname;
    end
    return sciname if comname.blank?
    "#{comname.name} (#{sciname})"
  end

  def leading_name(options = {})
    if c = common_name(options)
      return c.name
    end
    return name
  end

  def observations_count_with_descendents
    Observation.of(self).count
  end

  def descendants_count
    taxon_ancestors_as_ancestor.count
  end

  def taxon_changes_count
    (taxon_changes.map(&:id) +
     taxon_change_taxa.map(&:taxon_change_id)).uniq.length
  end

  def taxon_schemes_count
    taxon_schemes.size
  end

  #
  # Test whether this taxon's range overlaps a place
  #
  # def range_overlaps?(place)
  #   # looks like georuby doesn't support intersection just yet, probably 
  #   # because MySQL only supports intersections of minimum bounding 
  #   # rectangles.  Kinda stupid...
  #   self.range.geom.intersects? place.geom
  # end
  
  #
  # Test whether this taxon is in another taxon (e.g. Anna's Humminbird is in 
  # Class Aves)
  #
  def in_taxon?(taxon)
    # self.lft > taxon.lft && self.rgt < taxon.rgt
    target_id = taxon.is_a?(Taxon) ? taxon.id : taxon.to_i
    ancestor_ids.include?(target_id)
  end
  
  def graft(options = {})
    ratatosk.graft(self, options)
  rescue RatatoskGraftError, Timeout::Error, NameProviderError => e
    if species_or_lower? && name.split(' ').size > 1
      parent_name = name.split(' ')[0..-2].join(' ')
      parent = Taxon.single_taxon_for_name(parent_name)
      parent ||= Taxon.import(parent_name, :exact => true)
      if parent && parent.can_be_grafted_to && rank_level && parent.rank_level && parent.rank_level > rank_level && [GENUS, SPECIES].include?( parent.rank )
        self.update_attributes(:parent => parent)
      end
    end
    raise e unless grafted?
  end

  def graft_silently(options = {})
    graft(options)
  rescue RatatoskGraftError, Timeout::Error, NameProviderError => e
    Rails.logger.error "[ERROR #{Time.now}] Failed to graft #{self}: #{e}"
  end
  
  def grafted?
    return false if new_record? # New records haven't been grafted
    return false if self.name != 'Life' && ancestry.blank?
    return false if !kingdom? && Taxon::LIFE && parent_id === Taxon::LIFE.id
    true
  end
  
  def self_and_ancestors
    [ancestors, self].flatten
  end

  def self_and_ancestor_ids
    [ancestor_ids, id].flatten
  end
  
  def root?
    parent_id.nil?
  end
  
  def move_to_child_of( taxon )
    update_attributes( parent: taxon )
  end
  
  def default_name(options = {})
    options[:locale] ||= locale
    options[:user] ||= current_user
    TaxonName.choose_default_name(taxon_names, options)
  end
  
  def scientific_name
    TaxonName.choose_scientific_name(taxon_names)
  end
  
  #
  # Return just one common name.  Defaults to the first English common name, 
  # then first name of unspecified language (not-not-English), then the first 
  # common name of any language failing that
  #
  def common_name(options = {})
    options[:user] ||= current_user
    TaxonName.choose_common_name(taxon_names, options)
  end

  def common_name_string
    common_name.try(:name)
  end

  def name_with_rank
    if rank_level && rank_level < SPECIES_LEVEL
      r = case rank
        when SUBSPECIES then "ssp."
        when VARIETY then "var."
        when FORM then "f."
        else rank
      end
      pieces = name.split
      "#{pieces[0..-2].join(' ')} #{r} #{pieces.last}"
    elsif species?
      name
    else
      "#{rank.capitalize} #{name}"
    end
  end
  
  #
  # Create a scientific taxon name matching this taxon's name if one doesn't
  # already exist.
  #
  def set_scientific_taxon_name
    unless taxon_names.exists?(["name = ?", name])
      self.taxon_names << TaxonName.new(
        :name => name,
        :source => source,
        :source_identifier => source_identifier,
        :source_url => source_url,
        :name_provider => name_provider,
        :lexicon => TaxonName::LEXICONS[:SCIENTIFIC_NAMES],
        :is_valid => true
      )
    end
  end

  def set_photo_from_observations
    return true if photos.count > 0
    return unless obs = observations.has_quality_grade( Observation::RESEARCH_GRADE ).first
    return unless photo = obs.observation_photos.sort_by{ |op| op.position || op.id }.first.try(:photo)
    self.photos << photo
    Taxon.update_ancestor_photos( self, photo )
  end

  # mostly just a convenience for populating an empty database
  def set_photo_from_external
    return true if photos.count > 0
    return unless photo = photos_with_backfill.first
    self.photos << photo
    Taxon.update_ancestor_photos( self, photo )
  end
  
  # Override assignment method provided by has_many to ensure that all
  # callbacks on photos and taxon_photos get called, including after_destroy
  def photos=(new_photos)
    taxon_photos.each do |taxon_photo|
      taxon_photo.destroy unless new_photos.detect{|p| p.id == taxon_photo.photo_id}
    end
    new_photos.each do |photo|
      taxon_photos.build(:photo => photo) unless photos.detect{|p| p.id == photo.id}
    end
  end


  def taxon_photos_with_backfill(options = {})
    options[:limit] ||= 9
    if taxon_photos.loaded?
      chosen_taxon_photos = taxon_photos.sort_by{|tp| tp.position || tp.id }[0...options[:limit]]
    else
      chosen_taxon_photos = taxon_photos.includes({ photo: :flags }).
        order("taxon_photos.position ASC NULLS LAST, taxon_photos.id ASC").
        limit(options[:limit])
    end
    if chosen_taxon_photos.size < options[:limit]
      descendant_taxon_photos = TaxonPhoto.joins(:taxon).includes({ photo: :flags }).
        order( "taxon_photos.id ASC" ).
        limit( options[:limit] - chosen_taxon_photos.size ).
        where( "taxa.ancestry LIKE '#{ancestry}/#{id}%'" ).
        where( "taxa.is_active = ?", true ).
        where( "taxon_photos.id NOT IN (?)", chosen_taxon_photos.map(&:id) )
      chosen_taxon_photos += descendant_taxon_photos.to_a
    end
    chosen_taxon_photos
  end

  #
  # Fetches associated user-selected FlickrPhotos if they exist, otherwise
  # gets the the first :limit Create Commons-licensed photos tagged with the
  # taxon's scientific name from Flickr.  So this will return a heterogeneous
  # array: part FlickrPhotos, part api responses
  #
  def photos_with_backfill(options = {})
    chosen_taxon_photos = taxon_photos_with_backfill(options)
    chosen_photos = chosen_taxon_photos.map(&:photo)
    flickr_chosen_photos = []
    if !options[:skip_external] && chosen_photos.size < options[:limit] && self.auto_photos
      search_params = {
        tags: name.gsub(' ', '').strip,
        per_page: options[:limit] - chosen_photos.size,
        license: '1,2,3,4,5,6', # CC licenses
        extras: FlickrCache::EXTRAS,
        sort: 'relevance',
        safe_search: '1'
      }
      r = FlickrCache.fetch(flickr, "photos", "search", search_params)
      r = [] if r.blank?
      flickr_chosen_photos = if r.respond_to?(:map)
        r.map{|fp| fp.respond_to?(:url_s) && fp.url_s ? FlickrPhoto.new_from_api_response(fp) : nil}.compact
      else
        []
      end
      flickr_ids = chosen_photos.map{ |p| p.native_photo_id }
      chosen_photos += flickr_chosen_photos.reject do |fp|
        flickr_ids.include?(fp.id)
      end
    end
    chosen_photos.to_a
  end
  
  def photos_cache_key
    "taxon_photos_#{id}"
  end
  
  def photos_with_external_cache_key
    "taxon_photos_external_#{id}"
  end
  
  def observation_photos(options = {})
    options = {:page => 1}.merge(options).merge(
      :conditions => ["taxa.id = ?", id]
    )
    Photo.joins(observations: :taxon).where(options[:conditions]).
      paginate(options)
  end
  
  def phylum
    ancestors.where(rank: "phylum").first
  end

  def taxon_cant_be_its_own_ancestor
    if ancestor_ids.include?(id)
      errors.add(self.name, "can't be its own ancestor")
    end
  end
  
  def rank_level_for_taxon_and_parent_must_not_be_nil
    return if parent.nil?
    
    if parent.rank_level.nil? || rank_level.nil?
      errors.add(self.name, "rank level for taxon and parent must not be nil")
    end
  end
  
  def rank_level_must_be_finer_than_parent
    return if parent.nil?
    return unless is_active
    
    if parent.rank_level.to_f <= rank_level.to_f
      errors.add(self.name, "rank level must be finer than parent")
    end
  end
  
  def rank_level_must_be_coarser_than_children
    return if new_record?
    if (children.where(is_active: true).any?{ |e| e.rank_level.nil? }  || rank_level.nil?) || (children.where(is_active: true).any?{ |e| e.rank_level.to_f >= rank_level.to_f })
      errors.add(self.name, "rank level must be coarser than children")
    end
  end
  
  def only_inactive_children_if_inactive
    return if new_record? || is_active
    if !@skip_only_inactive_children_if_inactive && children.any?{ |e| e.is_active }
      errors.add(self.name, "must only have inactive children to be inactive itself")
    end
  end
    
  def active_parent_if_active
    return if parent.nil? || !is_active
    return if parent.is_active
    return if TaxonChange.uncommitted.output_taxon( parent ).exists?
    errors.add( self.name, "must have a parent that is active or the output of a draft taxon change to be active itself" )
  end

  def can_only_be_featured_if_photos
    if !featured_at.blank? && taxon_photos.blank?
      errors.add(:featured_at, "can only be set if the taxon has photos")
    end
  end

  def validate_locked
    if !@skip_locks && ancestry_changed? && (locked_ancestor = self.ancestors.is_locked.first)
      errors.add(:ancestry, "includes a locked taxon (#{locked_ancestor}), " +
        "so this cannot be added as a descendent.  Either unlock the " + 
        "locked taxon or merge this taxon with an existing one.")
    end
  end
  
  def get_upstream_taxon_framework(supplied_ancestor_ids = self.ancestor_ids)
    candidate = TaxonFramework.joins( "JOIN taxa t ON t.id = taxon_frameworks.taxon_id" ).
      where( "taxon_id IN (?) AND taxon_frameworks.rank_level IS NOT NULL AND taxon_frameworks.rank_level <= ?", supplied_ancestor_ids, rank_level ).
      order( "t.rank_level ASC" ).first
    
    if candidate
      blocker = TaxonFramework.joins( "JOIN taxa t ON t.id = taxon_frameworks.taxon_id" ).
        where( "taxon_id IN (?) AND taxon_frameworks.rank_level IS NOT NULL AND t.rank_level < ?", supplied_ancestor_ids, candidate.taxon.rank_level ).first
      unless blocker
        return candidate
      end
      return nil
    end
  end
      
  def has_ancestry_and_active_if_taxon_framework
    return true unless taxon_framework && taxon_framework.covers?
    return true unless ancestry_changed? || is_active_changed?
    return true unless ancestry.nil? || is_active == false
    errors.add( :base, "taxa with attached taxon frameworks must have ancestries and be active. Remove the taxon framework first" )
    true
  end
  
  def graftable_destination_relative_to_taxon_framework_coverage
    return true unless new_record? || ancestry_changed?
    return true if ancestry.nil? || !is_active
    if destination_taxon_framework = parent.taxon_framework
      if !skip_taxon_framework_checks && destination_taxon_framework && destination_taxon_framework.covers? && destination_taxon_framework.taxon_curators.any? && ( current_user.blank? || ( !current_user.blank? && !destination_taxon_framework.taxon_curators.where( user: current_user ).exists? ) )
        errors.add( :ancestry, "destination #{destination_taxon_framework.taxon} has a curated taxon framework attached to it. Contact the curators of that taxon to request changes." )
      end
    elsif destination_upstream_taxon_framework = parent.get_upstream_taxon_framework
      if !skip_taxon_framework_checks && destination_upstream_taxon_framework && parent.rank_level > destination_upstream_taxon_framework.rank_level && destination_upstream_taxon_framework.taxon_curators.any? && ( current_user.blank? || ( !current_user.blank? && !destination_upstream_taxon_framework.taxon_curators.where( user: current_user ).exists? ) ) 
        errors.add( :ancestry, "destination #{destination_upstream_taxon_framework.taxon} covered by a curated taxon framework. Contact the curators of that taxon to request changes." )
      end
    end
    true
  end
  
  def can_be_grafted_to
    if !skip_taxon_framework_checks && taxon_framework && taxon_framework.covers? && taxon_framework.taxon_curators.any? && (current_user.blank? || ( !current_user.blank? && !taxon_framework.taxon_curators.where( user: current_user ).exists? ) )
      return false
    end
    upstream_taxon_framework = get_upstream_taxon_framework
    if !skip_taxon_framework_checks && upstream_taxon_framework && rank_level > upstream_taxon_framework.rank_level && upstream_taxon_framework.taxon_curators.any? && ( current_user.blank? || ( !current_user.blank? && !upstream_taxon_framework.taxon_curators.where( user: current_user ).exists? ) ) 
      return false
    end
    true
  end
  
  def has_taxon_framework_relationship
    return false if taxon_framework_relationship_id.nil?
    true
  end
  
  def reasess_taxon_framework_relationship_after_move
    tfr = taxon_framework_relationship
    if tf = tfr.taxon_framework
      unless upstream_taxon_framework == tf
        tfr.destroy
        update_attributes( taxon_framework_relationship_id: nil )
      end
    end
  end
 
  def upstream_taxon_framework
    return @upstream_taxon_framework if @upstream_taxon_framework
    @upstream_taxon_framework = get_upstream_taxon_framework
    return @upstream_taxon_framework
  end
  
  def get_complete_taxon_framework_for_internode_or_root
    if taxon_framework && taxon_framework.covers? && taxon_framework.complete
      upstream_taxon_framework_including_root = taxon_framework
    else
      upstream_taxon_framework_including_root = upstream_taxon_framework
      return nil unless upstream_taxon_framework_including_root && upstream_taxon_framework_including_root.complete
      return nil unless upstream_taxon_framework_including_root.rank_level < rank_level
    end
    return upstream_taxon_framework_including_root
  end

  def graftable_relative_to_taxon_framework_coverage
    return true unless ancestry_changed? && !ancestry_was.nil?
    upstream_taxon_framework = get_upstream_taxon_framework( ancestry_was.split("/") )
    if !skip_taxon_framework_checks && upstream_taxon_framework && upstream_taxon_framework.taxon_curators.any? && ( current_user.blank? || ( !current_user.blank? && !upstream_taxon_framework.taxon_curators.where( user: current_user ).exists? ) )
      errors.add( :ancestry, "covered by a curated taxon framework attached to #{upstream_taxon_framework.taxon}. Contact the curators of that taxon to request changes." )
    end
    true
  end

  def user_can_edit_attributes
    return true unless is_active
    return true if current_user.blank?
    current_user_curates_taxon = protected_attributes_editable_by?( current_user )
    PROTECTED_ATTRIBUTES_FOR_CURATED_TAXA.each do |a|
      if changes[a] && !current_user_curates_taxon
        errors.add( a, :can_only_be_changed_by_a_curator_of_this_taxon )
      end
    end
    true
  end

  def protected_attributes_editable_by?( user )
    return true unless is_active
    return true if user && user.is_admin?
    upstream_taxon_framework = get_upstream_taxon_framework
    return true unless upstream_taxon_framework
    return true unless upstream_taxon_framework.taxon_curators.any?
    current_user_curates_taxon = false
    if user
      current_user_curates_taxon = upstream_taxon_framework.taxon_curators.where( user: user ).exists?
    end
    current_user_curates_taxon
  end
  
  def activated_protected_attributes_editable_by?( user )
    return true if user && user.is_admin?
    upstream_taxon_framework = get_upstream_taxon_framework
    return true unless upstream_taxon_framework
    return true unless upstream_taxon_framework.taxon_curators.any?
    current_user_curates_taxon = false
    if user
      current_user_curates_taxon = upstream_taxon_framework.taxon_curators.where( user: user ).exists?
    end
    current_user_curates_taxon
  end
  
  #
  # Determine whether this taxon is at or below the rank of species
  #
  def species_or_lower?
    return false if rank_level.blank?
    rank_level <= SPECIES_LEVEL
  end
  
  def infraspecies?
    return false if rank_level.blank?
    rank_level < SPECIES_LEVEL
  end
  
  def update_obs_iconic_taxa
    Observation.where(taxon_id: id).update_all(iconic_taxon_id: iconic_taxon_id)
    true
  end
  
  def update_unique_name(options = {})
    reload # there's a chance taxon names have been created since load
    return true unless default_name
    [default_name.name, name].uniq.each do |candidate|
      candidate = candidate.gsub(/[\.\'\?\!\\\/]/, '').downcase
      return if unique_name == candidate
      next if Taxon.exists?(:unique_name => candidate)
      Taxon.where(id: id).update_all(unique_name: candidate)
      break
    end
  end
  
  def wikipedia_summary( options = {} )
    return unless auto_description?
    locale = options[:locale] || I18n.locale
    td = taxon_descriptions.detect{|td| td.locale.to_s == locale.to_s}
    td ||= taxon_descriptions.detect{|td| td.locale.to_s =~ /^#{locale.to_s.split('-').first}/}
    sum = if td
      td.body.to_s[0..500]
    elsif locale.to_s =~ /^en-?/
      read_attribute(:wikipedia_summary)
    end
    if sum && sum.match(/^\d\d\d\d-\d\d-\d\d$/)
      last_try_date = DateTime.parse(sum)
      return nil if last_try_date > 1.week.ago
      options[:reload] = true
    end
    unless sum.blank? || options[:reload]
      return Nokogiri::HTML::DocumentFragment.parse(sum).to_s
    end
    
    if !new_record? && options[:refresh_if_blank]
      delay(priority: OPTIONAL_PRIORITY,
        unique_hash: { "Taxon::set_wikipedia_summary": id }).
        set_wikipedia_summary(:locale => locale)
    end
    nil
  end
  
  def set_wikipedia_summary( options = {} )
    unless auto_description?
      update_attributes( wikipedia_summary: false )
      self.taxon_descriptions.destroy_all
      return
    end
    locale = options[:locale] || I18n.locale
    w = options[:wikipedia] || WikipediaService.new(:locale => locale)
    wname = wikipedia_title.blank? ? name : wikipedia_title
    provider = nil
    
    if details = w.page_details(wname, options)
      pre_trunc = details[:summary]
      details[:summary] = details[:summary].split[0..75].join(' ')
      details[:summary] += '...' if pre_trunc > details[:summary]
      provider = "Wikipedia"
    end

    if details.blank? || details[:summary].blank?
      Taxon.where(id: self).update_all(wikipedia_summary: Date.today) if locale.to_s =~ /^en-?/
      return nil
    end
    
    if locale.to_s =~ /^en-?/
      Taxon.where(id: self).update_all( wikipedia_summary: details[:summary] )
    end
    td = taxon_descriptions.where(locale: locale).first
    td ||= self.taxon_descriptions.build(locale: locale)
    if td
      td.update_attributes(
        title: details[:title],
        body: details[:summary],
        provider_taxon_id: details[:id],
        url: details[:url],
        provider: provider || td.provider
      )
    end
    # the update_all above skips callbacks, and the wikipedia URL may have changes
    elastic_index!
    details[:summary]
  end

  def remove_wikipedia_summary_unless_auto_description
    self.wikipedia_summary = nil unless auto_description?
    true
  end

  def wikipedia_attribution( options = {} )
    locale = options[:locale] || I18n.locale
    locale_lang = locale.to_s.split( "-" ).first
    if td = taxon_descriptions.where( locale: locale_lang ).first
      title = td.title
      url = td.url
    else
      title = wikipedia_title || name
      url = "https://wikipedia.org/wiki/#{title.underscore}"
    end
    I18n.t( :wikipedia_attribution_cc_by_sa_3, title: title, locale: locale, url: url )
  end

  def ensure_parent_ancestry_in_ancestry
    if parent && parent.ancestry && ancestry && ancestry.index( parent.ancestry ) != 0
      self.ancestry = [parent.ancestry.split( "/ " ), parent.id].flatten.compact.join( "/" )
    end
    true
  end

  def unfeature_inactive
    self.featured_at = nil unless is_active?
    true
  end

  def auto_summary
    return if LIFE && id == LIFE.id
    translated_rank = if rank.blank?
      I18n.t( :rank, default: "rank" ).downcase
    else
      I18n.t( "ranks.#{rank}", default: rank ).downcase
    end
    summary = if kingdom?
      I18n.t(:taxon_is_kingdom_of_life_with_x_observations, taxon: name, count: observations_count )
    elsif iconic_taxon_id
      iconic_name = if parent && iconic_taxon_id == id
        parent.iconic_taxon_name
      else
        iconic_taxon_name
      end
      unless iconic_taxon_name.blank?
        I18n.t(
          "taxon_is_a_rank_of_#{iconic_name.downcase.underscore}_with_x_observations",
          taxon: name,
          rank: translated_rank,
          count: observations_count,
          default: I18n.t(
            :taxon_is_a_rank_in_iconic_taxon_with_x_observations,
            taxon: name,
            rank: translated_rank,
            iconic_taxon: iconic_name,
            count: observations_count
          )
        )
      end
    end
    summary = I18n.t(:taxon_is_a_rank, taxon: name, rank: translated_rank ) if summary.blank?
    summary
  end
  
  def merge(reject)
    raise "Can't merge a taxon with itself" if reject.id == self.id
    reject_taxon_names = reject.taxon_names.all.to_a
    reject_taxon_scheme_taxa = reject.taxon_scheme_taxa.all.to_a
    # otherwise it will screw up merge_has_many_associations
    TaxonAncestor.where(:taxon_id => reject.id).delete_all
    TaxonAncestor.where(:ancestor_taxon_id => reject.id).delete_all
    merge_has_many_associations(reject)
    
    # Merge ListRules and other polymorphic assocs
    ListRule.where(operand_id: reject.id, operand_type: Taxon.to_s).
      update_all(operand_id: id)
    
    # Keep reject colors if keeper has none
    self.colors << reject.colors if colors.blank?
    
    # Move reject child taxa to the keeper
    reject.children.each {|child| child.move_to_child_of(self)}
    
    # Update or destroy merged taxon scheme taxa
    reject_taxon_scheme_taxa.each do |reject_tst|
      reject_tst.reload
      reject_tst_name = reject_tst.taxon_name
      if taxon_name = self.taxon_names.where(:lexicon => TaxonName::SCIENTIFIC_NAMES, :name => reject_tst_name.name).first
        reject_tst.update_attributes(:taxon_name_id => taxon_name.id)
      end
      unless reject_tst.valid?
        Rails.logger.info "[INFO] Destroying #{reject_tst} while merging taxon " + 
          "#{reject.id} into taxon #{id}: #{reject_tst.errors.full_messages.to_sentence}"
        reject_tst.destroy 
        next
      end
    end
    
    # Update or destroy merged taxon_names
    reject_taxon_names.each do |taxon_name|
      taxon_name.reload
      if taxon_name.is_scientific_names? && taxon_name.is_valid?
        taxon_name.update_attributes(:is_valid => false)
      end
      unless taxon_name.valid?
        Rails.logger.info "[INFO] Destroying #{taxon_name} while merging taxon " + 
          "#{reject.id} into taxon #{id}: #{taxon_name.errors.full_messages.to_sentence}"
        taxon_name.destroy
      end
    end
    
    %w(flags).each do |association|
      send(association, :reload => true).each do |associate|
        associate.destroy unless associate.valid?
      end
    end

    Taxon.delay(:priority => INTEGRITY_PRIORITY).set_iconic_taxon_for_observations_of(id)
    
    reject.reload
    Rails.logger.info "[INFO] Merged #{reject} into #{self}"
    reject.destroy
  end
  
  def to_tags
    tags = []
    if grafted?
      tags += self_and_ancestors.map do |taxon|
        unless taxon.root?
          name_pieces = taxon.name.split
          name_pieces.delete('subsp.')
          if name_pieces.size == 3
            ["taxonomy:species=#{name_pieces[1]}", "taxonomy:trinomial=#{name_pieces.join(' ')}"]
          elsif name_pieces.size == 2
            ["taxonomy:species=#{name_pieces[1]}", "taxonomy:binomial=#{taxon.name.strip}"]
          else
            ["taxonomy:#{taxon.rank}=#{taxon.name.strip}", taxon.name.strip]
          end
        end
      end.flatten.compact
    else
      name_pieces = name.split
      name_pieces.delete('subsp.')
      if name_pieces.size == 3
        tags << "taxonomy:trinomial=#{name_pieces.join(' ')}"
        tags << "taxonomy:binomial=#{name_pieces[0]} #{name_pieces[1]}"
      elsif name_pieces.size == 2
        tags << "taxonomy:binomial=#{name.strip}"
      else
        tags << "taxonomy:#{rank}=#{name.strip}"
      end
    end
    tags += taxon_names.map{|tn| tn.name.strip if tn.is_valid?}.compact
    tags += taxon_names.map do |taxon_name|
      unless taxon_name.lexicon == TaxonName::LEXICONS[:SCIENTIFIC_NAMES]
        "taxonomy:common=#{taxon_name.name.strip}"
      end
    end.compact.flatten
    
    tags.compact.flatten.uniq
  end
  
  def parent_id=(parent_id)
    return unless !parent_id.blank? && Taxon.find_by_id(parent_id)
    super
  end
  
  def ancestor_of?(taxon)
    taxon.ancestor_ids.include?(id)
  end
  
  def descendant_of?(taxon)
    ancestor_ids.include?(taxon.id)
  end
  
  # TODO make this work for different conservation status sources
  def conservation_status_name
    return nil if conservation_status.blank?
    IUCN_STATUSES[conservation_status]
  end
  
  def conservation_status_code
    return nil if conservation_status.blank?
    IUCN_STATUS_CODES[conservation_status_name]
  end
  
  def threatened?(options = {})
    return true if globally_threatened?
    return threatened_in_place?(options[:place]) unless options[:place].blank?
    return threatened_in_lat_lon?(options[:latitude], options[:longitude]) unless options[:latitude].blank?
    false
  end

  def establishment_means_in_place?(means, place, options = {})
    means = [ means ] unless means.is_a?(Array)
    places = Place.param_to_array(place)
    return false if places.blank?
    lt = listed_taxa_with_establishment_means
    place_ancestor_ids = (places.map(&:id) +
      places.map{ |p| p.ancestry.to_s.split("/").map(&:to_i) }).flatten.uniq
    if options[:closest]
      most_specific_lt = lt.
        select{ |l| l.establishment_means && place_ancestor_ids.include?(l.place_id) }.
        sort_by{ |l| l.place.bbox_area || 0 }.first
      return false if most_specific_lt.blank?
      means.include?( most_specific_lt.establishment_means)
    else
      !!lt.
        select{ |l| l.establishment_means && place_ancestor_ids.include?(l.place_id) }.
        detect{ |l| means.include?( l.establishment_means) }
    end
  end

  def globally_threatened?
    return conservation_status >= IUCN_NEAR_THREATENED unless conservation_status.blank?
    if association(:conservation_statuses).loaded?
      conservation_statuses.detect{|cs| cs.place_id.blank? && cs.iucn >= IUCN_NEAR_THREATENED}
    else
      conservation_statuses.where("place_id IS NULL AND iucn >= ?", IUCN_NEAR_THREATENED).exists?
    end
  end

  def threatened_in_place?(place)
    places = Place.param_to_array(place)
    return false if places.blank?
    cs = if association(:conservation_statuses).loaded?
      place_ancestor_ids = (places.map(&:id) +
        places.map{ |p| p.ancestry.to_s.split("/").map(&:to_i) }).flatten.uniq
      place_ancestor_ids << nil
      conservation_statuses.detect{ |c|
        place_ancestor_ids.include?(c.place_id) && c.iucn.to_i > IUCN_LEAST_CONCERN }
    else
      conservation_statuses.where("place_id IN (#{ places.map(&:id).join(',') }) OR
        place_id::text IN (#{ListedTaxon.place_ancestor_ids_sql(places.map(&:id))})
        OR place_id IS NULL").where("iucn > ?", IUCN_LEAST_CONCERN).first
    end
    return !cs.nil?
  end
  
  def threatened_status(options = {})
    if place_id = options[:place_id]
      place = Place.find_by_id(place_id)
      if association(:conservation_statuses).loaded?
        conservation_statuses.select{|cs| ([nil, place.ancestry.to_s.split("/")].flatten.include? cs.place_id.to_s) && cs.iucn.to_i > IUCN_LEAST_CONCERN}.max_by{|cs| cs.iucn.to_i}
      else
        conservation_statuses.where("place_id::text IN (#{ListedTaxon.place_ancestor_ids_sql(place_id)}) OR place_id IS NULL").where("iucn > ?", IUCN_LEAST_CONCERN).max_by{|cs| cs.iucn.to_i}
      end
    elsif (lat = options[:latitude]) && (lon = options[:longitude])
      conservation_statuses.for_lat_lon(lat,lon).where("iucn > ?", IUCN_LEAST_CONCERN).max_by{|cs| cs.iucn.to_i}
    else
      if association(:conservation_statuses).loaded?
        conservation_statuses.select{|cs| cs.place_id.blank? && cs.iucn.to_i > IUCN_LEAST_CONCERN}.max_by{|cs| cs.iucn.to_i}
      else
        conservation_statuses.where("place_id IS NULL").where("iucn > ?", IUCN_LEAST_CONCERN).max_by{|cs| cs.iucn.to_i}
      end
    end
  end

  def threatened_in_lat_lon?(lat, lon)
    return false if lat.blank? || lon.blank?
    log_timer do
      ConservationStatus.for_taxon(self).for_lat_lon(lat,lon).exists?
    end
  end

  def self.max_geoprivacy( taxon_ids, options = {} )
    return if taxon_ids.blank?
    target_taxon_ids = [
      taxon_ids,
      Taxon.where( "id IN (?)", taxon_ids).pluck(:ancestry).map{|a| a.to_s.split( "/" ).map(&:to_i)}
    ].flatten.compact.uniq
    global_status = ConservationStatus.where("place_id IS NULL AND taxon_id IN (?)", target_taxon_ids).order("iucn ASC").last
    if global_status && global_status.geoprivacy == Observation::PRIVATE
      return global_status.geoprivacy
    end
    geoprivacies = []
    geoprivacies << global_status.geoprivacy if global_status
    geoprivacies += ConservationStatus.
      where( "taxon_id IN (?)", target_taxon_ids ).
      for_lat_lon( options[:latitude], options[:longitude] ).pluck( :geoprivacy )
    return Observation::PRIVATE if geoprivacies.include?( Observation::PRIVATE )
    return Observation::OBSCURED if geoprivacies.include?( Observation::OBSCURED )
    geoprivacies.size == 0 ? nil : Observation::OPEN
  end

  def geoprivacy( options = {} )
    Taxon.max_geoprivacy( [id], options )
  end

  def add_to_intersecting_places
    Place.
        where("places.admin_level IN (?)", [Place::COUNTRY_LEVEL, Place::STATE_LEVEL, Place::COUNTRY_LEVEL]).
        intersecting_taxon(self).
        find_each(:select => "places.id, admin_level, check_list_id, taxon_ranges.id AS taxon_range_id", :include => :check_list) do |place|
      place.check_list.try(:add_taxon, self, :taxon_range_id => place.taxon_range_id)
    end
  end
  
  def iconic_taxon_name
    ICONIC_TAXA_BY_ID[iconic_taxon_id].try(:name)
  end
  
  # ancestry overrides - some ancestry methods iterate over ALL descendants 
  # in memory.  It's database agnostic but massively ineffecient
  def update_descendants_with_new_ancestry
    return true if ancestry_callbacks_disabled?
    ancestry_column = self.class.base_class.ancestry_column.to_s
    return true unless changed.include?(ancestry_column) && !new_record? && valid?
    old_ancestry = send("#{ancestry_column}_was")
    old_ancestry = old_ancestry.blank? ? id : "#{old_ancestry}/#{id}"
    new_ancestry = send(ancestry_column)
    new_ancestry = new_ancestry.blank? ? id : "#{new_ancestry}/#{id}"
    self.class.base_class.where(descendant_conditions).update_all(
      "#{ancestry_column} = regexp_replace(#{ancestry_column}, '^#{old_ancestry}', '#{new_ancestry}')")
    Taxon.delay(:priority => INTEGRITY_PRIORITY).update_descendants_with_new_ancestry(id, child_ancestry)
    true
  end
  
  def default_photo
    @default_photo ||= if taxon_photos.loaded?
      taxon_photos.sort_by{|tp| tp.position || tp.id}.first.try(:photo)
    else
      taxon_photos.includes(:photo).first.try(:photo)
    end
    @default_photo
  end
  
  def self.update_descendants_with_new_ancestry(taxon, child_ancestry_was)
    taxon = Taxon.find_by_id(taxon) unless taxon.is_a?(Taxon)
    return unless taxon
    Rails.logger.info "[INFO #{Time.now}] updating descendants of #{taxon}"
    Taxon.where(taxon.descendant_conditions).find_in_batches do |batch|
      batch.each do |t|
        t.without_ancestry_callbacks do
          t.set_iconic_taxon
          t.update_obs_iconic_taxa
        end
      end
    end
  end
  
  def apply_orphan_strategy
    return if ancestry_callbacks_disabled?
    return if new_record?
    Taxon.delay(:priority => INTEGRITY_PRIORITY).apply_orphan_strategy(child_ancestry)
  end
  
  def self.apply_orphan_strategy(child_ancestry_was)
    # return unless taxon
    Rails.logger.info "[INFO #{Time.now}] applying orphan strategy to #{child_ancestry_was}"
    descendant_conditions = [
      "ancestry = ? OR ancestry LIKE ?", 
      child_ancestry_was, "#{child_ancestry_was}/%"
    ]
    Taxon.where(descendant_conditions).find_in_batches do |batch|
      batch.each do |t|
        t.without_ancestry_callbacks do
          t.destroy
        end
      end
    end
  end
  
  def view_context
    FakeView
  end
  
  def image_url
    view_context.taxon_image_url(self)
  end
  
  def photo_url
    if @default_photo || (taxon_photos.loaded? && taxon_photos.size > 0)
      return image_url
    end
    taxon_photos.blank? ? nil : image_url
  end

  def taxon_range_kml_url
    return nil unless ranges = taxon_ranges_without_geom
    tr = ranges.detect{|tr| !tr.range.blank?} || ranges.first
    tr ? tr.kml_url : nil
  end

  def all_names
    taxon_names.map(&:name)
  end

  def self.import(name, options = {})
    skip_grafting = options.delete(:skip_grafting)
    name = normalize_name(name)
    ancestor = options.delete(:ancestor)
    ratatosk_instance = options.delete(:ratatosk) || ratatosk
    external_names = begin
      ratatosk_instance.find(name)
    rescue Timeout::Error => e
      []
    end
    external_names.select!{|en| en.name.downcase == name.downcase} if options[:exact]
    return nil if external_names.blank?
    external_names.each do |en|
      if en.save && !skip_grafting && !en.taxon.grafted? && en.taxon.persisted?
        en.taxon.graft_silently
      end
    end
    external_taxa = external_names.map(&:taxon)
    taxon = external_taxa.detect do |t|
      if ancestor
        t.name.downcase == name.downcase && t.ancestor_ids.include?(ancestor.id)
      else
        t.name.downcase == name.downcase
      end
    end
    taxon
  end

  def editable_by?( user )
    return false unless user.is_a?( User )
    return true if user.is_admin?
    return true if user.is_curator? && get_upstream_taxon_framework
    user.is_curator? && rank_level.to_i < ORDER_LEVEL
  end

  def mergeable_by?(user, reject)
    return true if user.is_admin?
    return true if name == reject.name
    return true if creator_id == user.id && reject.creator_id == user.id
    if reject.identifications.count == 0 && reject.observations.count == 0 && reject.listed_taxa.count == 0 && reject.taxon_scheme_taxa.count == 0
      return true
    end
    false
  end

  def deleteable_by?(user)
    return true if user.is_admin?
    return true if new_record?
    return false if taxon_changes.exists? || taxon_change_taxa.exists?
    return false if children.exists?
    return false if identifications.exists?
    return false if controlled_term_taxa.exists?
    return false if ProjectObservationRule.where( operand_type: "Taxon", operand_id: id ).exists?
    return false if ObservationFieldValue.joins(:observation_field).where( "observation_fields.datatype = 'taxon' AND value = ?", id.to_s ).exists?
    return false if TaxonChange.joins( taxon: :taxon_ancestors ).where( "taxon_ancestors.ancestor_taxon_id = ?", id ).exists?
    return false if TaxonChangeTaxon.joins( taxon: :taxon_ancestors ).where( "taxon_ancestors.ancestor_taxon_id = ?", id ).exists?
    creator_id == user.id
  end

  def match_descendants(taxon_hash)
    Taxon.match_descendants_of_id(id, taxon_hash)
  end

  # Used primarily in get_gbif_id. For that particular API, it is useful
  # to know the ancestor of a taxon that fits one of the major ranks, rather
  # than a sibtribe or infrafamily which may nto be as common. This
  # 'preferred' ancestor (term borrowed from Taxon::PREFERRED_RANKS) can be
  # used to give extra context when searching taxa (e.g. the Aotus in Fabaceae)
  def preferred_uninomial_ancestor
    Taxon::PREFERRED_RANKS.reverse.each do |r|
      # don't use binomials as preferred ancestors, use genera or above
      next if [ "species", "subspecies", "variety" ].include?( r )
      # the rank_level of the ancestor will be higher than its own rank_level
      next if rank_level && rank_level >= Taxon::RANK_LEVELS[r]
      # if the taxon has an ancestor at this next rank, return it
      if ancestor = self.send("find_#{ r }")
        return ancestor if ancestor != self
      end
    end
    nil
  end

  def get_gbif_id
    if taxon_scheme_taxa.loaded? && tst = taxon_scheme_taxa.detect{|r| r.taxon_scheme.title == 'GBIF'}
      return tst.source_identifier
    end
    # make sure the GBIF TaxonScheme exists
    gbif = TaxonScheme.where( title: "GBIF" ).first
    unless gbif = TaxonScheme.where( title: "GBIF" ).first
      unless gbif_source = Source.where( url: "http://www.gbif.org" ).first
        gbif_source = Source.create!(
          title: "Global Biodiversity Information Facility",
          in_text: "GBIF",
          url: "http://www.gbif.org"
        )
      end
      gbif = TaxonScheme.create!( title: "GBIF", source: gbif_source )
    end
    # return their ID if we know it
    if scheme = TaxonSchemeTaxon.where(taxon_scheme: gbif, taxon_id: id).first
      return scheme.source_identifier
    end
    params = { name: name }
    if ancestor = preferred_uninomial_ancestor
      params[ancestor.rank] = ancestor.name
    end
    json = begin
      GbifService.species_match(params: params)
    rescue Timeout::Error, SocketError => e
      # probably GBIF is down or throttling us
      Rails.logger.error "[ERROR #{Time.now}] #{e}"
      nil
    end
    if json && json["canonicalName"] == name
      if json["usageKey"]
        begin
          tst = TaxonSchemeTaxon.create!(taxon_scheme: gbif, taxon_id: id, source_identifier: json["usageKey"])
        rescue ActiveRecord::RecordInvalid => e
          Rails.logger.error "[ERROR #{Time.now}] Failed to add GBIF taxon #{name}, ID:#{json['usageKey']}: #{e}"
        end
        return json["usageKey"]
      else
        TaxonSchemeTaxon.create(taxon_scheme: gbif, taxon_id: id, source_identifier: nil)
      end
    end
    nil
  end

  def has_ancestor_taxon_id(ancestor_id)
    return true if id == ancestor_id
    return false if ancestry.blank?
    !! ancestry.match(/(^|\/)#{ancestor_id}(\/|$)/)
  end

  def atlased?
    return @atlased unless @atlased.nil?
    @atlased = atlas && atlas.is_active? && atlas.presence_places.exists?
  end

  def cached_atlas_presence_places
    @cached_atlas_presence_places ||= atlas.presence_places if atlas
  end

  def current_synonymous_taxon( options = {} )
    return nil if is_active?
    without_taxon_ids = [options[:without_taxon_ids] || [], id].flatten.uniq
    synonymous_taxon = TaxonChange.committed.where( "type IN ('TaxonSwap', 'TaxonMerge')" ).
      joins( :taxon_change_taxa ).
      where( "taxon_change_taxa.taxon_id = ?", self ).
      where( "taxon_changes.taxon_id NOT IN (?)", without_taxon_ids ).order(:id).last.try(:output_taxon)
    return synonymous_taxon if synonymous_taxon.blank?
    if synonymous_taxon.is_active? || options[:inactive]
      return synonymous_taxon
    end
    candidates = synonymous_taxon.current_synonymous_taxa( without_taxon_ids: without_taxon_ids )
    return nil if candidates.size > 1
    candidates.first
  end

  def current_synonymous_taxa_from_split( options = {} )
    without_taxon_ids = [options[:without_taxon_ids] || [], id].flatten.uniq
    last_committed_split = TaxonSplit.committed.order( "taxon_changes.id desc" ).where( taxon_id: id ).first
    return [] if last_committed_split.blank?
    last_committed_split.output_taxa.map{|t|
      t.is_active? ? t : t.current_synonymous_taxa( without_taxon_ids: without_taxon_ids )
    }.flatten.uniq
  end

  def current_synonymous_taxa( options = {} )
    without_taxon_ids = [options[:without_taxon_ids] || [], id].flatten.uniq
    synonymous_taxa = current_synonymous_taxa_from_split( without_taxon_ids: without_taxon_ids )
    taxon_from_swaps_and_merge = current_synonymous_taxon( without_taxon_ids: without_taxon_ids )
    if taxon_from_swaps_and_merge
      synonymous_taxa << taxon_from_swaps_and_merge
    end
    if inactive_synonym_from_swaps_and_merge = current_synonymous_taxon( without_taxon_ids: without_taxon_ids, inactive: true )
      if inactive_synonym_synonyms = inactive_synonym_from_swaps_and_merge.current_synonymous_taxa( without_taxon_ids: without_taxon_ids )
        synonymous_taxa += inactive_synonym_synonyms
      end
    end
    synonymous_taxa.uniq
  end

  def flagged_with( flag, options = {} )
    elastic_index!
  end

  # Static ##################################################################

  def self.match_descendants_of_id(id, taxon_hash)
    taxon_hash['ancestry'].each{|ancestor|
      return true if id == ancestor.to_i 
    }
    false
  end

  def self.import_or_create(name, options = {})
    taxon = import(name, options)
    return taxon unless taxon.blank?
    options.delete(:ancestor)
    taxon = Taxon.create(options.merge(:name => name))
    taxon.graft_silently
    taxon
  end
  
  #
  # Count the number of taxa in the given rank.
  #
  # I don't like hard-coding it like this, so if you know an abstract way of 
  # getting at the column name associated with an attribute, or an aliased 
  # attribute like 'rank', please tell me.
  #
  def self.count_taxa_in_rank(rank)
    Taxon.count_by_sql(
      "SELECT COUNT(*) from #{Taxon.table_name} WHERE (rank = '#{rank.downcase}')"
    )
  end
  
  def self.normalize_rank(rank)
    return rank if rank.nil?
    rank = rank.gsub(/[^\w]/, '').downcase
    return rank if RANKS.include?(rank)
    return RANK_EQUIVALENTS[rank] if RANK_EQUIVALENTS[rank]
    rank
  end
  
  def self.remove_rank_from_name(name)
    pieces = name.split
    return name if pieces.size == 1
    pieces.map! {|p| p.gsub('.', '')}
    pieces.reject! {|p| (RANKS + RANK_EQUIVALENTS.keys).include?(p.downcase)}
    pieces.join(' ')
  end

  def self.normalize_name(name)
    if name =~ /.+ \(=.+?\) .+/
      pieces = name.match(/(.+) \(=.+?\) (.+)/)
      name = "#{pieces[1]} #{pieces[2]}"
    elsif name =~ /.+\(.+?\)/
      name = name[/.+\((.+?)\)/, 1]
    end
    name = name.gsub(/[\(\)\?]/, '')
    name = name.gsub(/^\W$/, '')
    Taxon.remove_rank_from_name(name)
  end
  
  # Convert an array of strings to taxa
  def self.tags_to_taxa(tags, options = {})
    scope = TaxonName.joins(:taxon)
    if options[:lexicon]
      scope = scope.where(
        lexicon: [options[:lexicon]].flatten.map{|l| [l, TaxonName.normalize_lexicon( l ) ]}.flatten
      )
    end
    scope = scope.where("taxon_names.is_valid = ?", true) if options[:valid]
    names = tags.map do |tag|
      next if tag.blank?
      if name = tag.match(/^taxonomy:\w+=(.*)/).try(:[], 1)
        name
      else
        name = Taxon.normalize_name(tag)
        next if PROBLEM_NAMES.include?(name.downcase)
        name
      end
    end.compact
    lower_names = names.map(&:downcase)
    scope = scope.where("lower(taxon_names.name) IN (?)", lower_names)
    taxon_names = scope.where("taxa.is_active = ?", true).all
    taxon_names = scope.all if taxon_names.blank? && options[:active] != true
    taxon_names = taxon_names.select do |tn|
      names.include?(tn.name) || !tn.name.match(/^([A-Z]|\d)+$/)
    end
    taxon_names = taxon_names.select{|tn| !tn.scientific? || tn.name.size > 2}
    taxon_names = taxon_names.compact.sort do |tn1,tn2|
      tn1_exact = names.include?(tn1.name) ? 1 : 0
      tn2_exact = names.include?(tn2.name) ? 1 : 0
      [tn2_exact, tn2.name.size] <=> [tn1_exact, tn1.name.size]
    end
    taxon_names.map{|tn| tn.taxon}.compact.uniq
  end
  
  def self.find_duplicates
    duplicate_counts = Taxon.group(:name).having("count(*) > 1").count
    num_keepers = 0
    num_rejects = 0
    for name in duplicate_counts.keys
      taxa = Taxon.where(name: name)
      Rails.logger.info "[INFO] Found #{taxa.size} duplicates for #{name}: #{taxa.map(&:id).join(', ')}"
      taxa.group_by(&:parent_id).each do |parent_id, child_taxa|
        Rails.logger.info "[INFO] Found #{child_taxa.size} duplicates within #{parent_id}: #{child_taxa.map(&:id).join(', ')}"
        next unless child_taxa.size > 1
        child_taxa = child_taxa.sort_by(&:id)
        keeper = child_taxa.shift
        child_taxa.each {|t| keeper.merge(t)}
        num_keepers += 1
        num_rejects += child_taxa.size
      end
    end
    
    Rails.logger.info "[INFO] Finished Taxon.find_duplicates.  Kept #{num_keepers}, removed #{num_rejects}."
  end
  
  def self.rebuild_without_callbacks
    before_validation.clear
    before_save.clear
    after_save.clear
    validates_associated.clear
    validates_presence_of.clear
    validates_uniqueness_of.clear
    restore_ancestry_integrity!
  end
  
  # Do something without all the callbacks.  This disables all callbacks and
  # validations and doesn't restore them, so IT SHOULD NEVER BE CALLED BY THE
  # APP!  The process should end after this is done.
  def self.without_callbacks(&block)
    before_validation.clear
    before_save.clear
    after_save.clear
    validates_associated.clear
    validates_presence_of.clear
    validates_uniqueness_of.clear
    yield
  end
  
  def self.set_iconic_taxon_for_observations_of(taxon)
    taxon = Taxon.find_by_id(taxon) unless taxon.is_a?(Taxon)
    return unless taxon
    Observation.where(taxon_id: taxon.id).update_all(iconic_taxon_id: taxon.iconic_taxon_id)
    sql = <<-SQL
      UPDATE observations SET iconic_taxon_id = #{taxon.iconic_taxon_id || 'NULL'}
      FROM taxa
      WHERE 
        observations.taxon_id = taxa.id AND 
        (#{Taxon.send :sanitize_sql, taxon.descendant_conditions.to_sql})
    SQL
    descendant_iconic_taxon_ids = taxon.descendants.iconic_taxa.select(:id).map(&:id)
    unless descendant_iconic_taxon_ids.blank?
      sql += " AND observations.iconic_taxon_id NOT IN (#{descendant_iconic_taxon_ids.join(',')})"
    end
    connection.execute sql
  end
  
  def self.occurs_in(minx, miny, maxx, maxy, startdate=nil, enddate=nil)
    startdate = startdate.nil? ? 100.years.ago.to_date : Date.parse(startdate) # wtf, only 100 years?!
    enddate = enddate.nil? ? Time.now.to_date : Date.parse(enddate)
    startdate = startdate.to_param
    enddate = enddate.to_param
    sql = """
      SELECT 
        t.*,
        o.count as count
      FROM
        col_taxa t
          JOIN 
            (SELECT 
                taxon_id, count(*) as count
              FROM observations 
              WHERE 
                observed_on > '#{startdate}' AND observed_on < '#{enddate}' AND
                latitude > '#{miny}' AND 
                longitude > '#{minx}' AND 
                latitude < '#{maxy}' AND 
                longitude < '#{maxx}'
              GROUP BY taxon_id) o
            ON o.taxon_id=t.record_id
    """
    Taxon.find_by_sql(sql)
  end

  def self.search_query(q)
    q = sanitize_query(q)
    if q.blank?
      q = q
      return [q, :all]
    end

    # for some reason 1-term queries don't return an exact match first if enclosed 
    # in quotes, so we only use them for multi-term queries
    q = if q =~ /\s/
      "\"^#{q}$\" | #{q}"
    else
      "^#{q}$ | #{q}"
    end
    [q, :extended]
  end
  
  def self.single_taxon_for_name(name, options = {})
    return if name.blank?
    return if PROBLEM_NAMES.include?(name.downcase)
    name = normalize_name(name)
    scope = TaxonName.limit(10).joins(:taxon).
      where("lower(taxon_names.name) = ?", name.strip.gsub(/[\s_]+/, ' ').downcase)
    scope = scope.where(options[:ancestor].descendant_conditions) if options[:ancestor]
    if options[:iconic_taxa]
      iconic_taxon_ids = options[:iconic_taxa].map do |it|
        if it.is_a?(Taxon)
          it.id
        elsif it.to_i == 0
          Taxon::ICONIC_TAXA_BY_NAME[it].try(:id)
        else
          it
        end
      end.compact
      scope = scope.where("taxa.iconic_taxon_id IN (?)", iconic_taxon_ids)
    end
    taxon_names = scope.to_a
    return taxon_names.first.taxon if taxon_names.size == 1
    taxa = taxon_names.map{|tn| tn.taxon}.compact
    # TODO search elasticsearch?
    # if taxa.blank?
    #   ...
    # end
    sorted = Taxon.sort_by_ancestry(taxa.compact)
    return if sorted.blank?
    return sorted.first if sorted.size == 1

    # if there's a single branch of matches, e.g. Homo and Homo sapiens, 
    # choose the most conservative, highest rank taxon
    if sorted.first.ancestor_of?(sorted.last)
      sorted.first

    # if only one result is grafted, choose that
    elsif sorted.select{|taxon| taxon.grafted?}.size == 1
      sorted.detect{|taxon| taxon.grafted?}

    # if none are grafted, choose the first
    elsif sorted.select{|taxon| taxon.grafted?}.size == 0
      taxon = sorted.detect{|t| t.taxon_names.detect{|tn| tn.name.downcase == name.downcase && tn.is_valid?}}
      taxon || sorted.first

    # if only one is active, choose the active one
    elsif sorted.select{|taxon| taxon.is_active?}.size == 1
      sorted.detect{|taxon| taxon.is_active?}

    # if the names are synonymous and share the same parent and only one is active, choose the active concept
    elsif taxon_names.map(&:name).uniq.size == 1 && taxa.map(&:parent_id).uniq.size == 1 && taxa.select(&:is_active?).size == 1
      taxon = sorted.detect do |taxon|
        taxon.is_active? && taxon.taxon_names.detect{|tn| tn.name.downcase == name.downcase && tn.is_valid?}
      end
      taxon || sorted.detect {|taxon| taxon.is_active?}

    # if names are synonymous but only one is valid, choose the valid one
    elsif taxon_names.map(&:name).uniq.size == 1 && taxon_names.select(&:is_valid?).size == 1
      taxon_names.detect(&:is_valid?).taxon

    # else assume there are > 1 legit synonyms and refuse to make a decision
    else
      nil
    end
  end
  
  def self.default_json_options
    {
      :methods => [:default_name, :photo_url, :iconic_taxon_name, :conservation_status_name],
      :except => [:delta, :auto_description, :source_url, 
        :source_identifier, :creator_id, :updater_id, :version, 
        :featured_at, :auto_photos, :locked],
      :include => {
        :taxon_photos => {
          :include => {
            :photo => {
              :methods => [:license_code, :attribution],
              :except => [:original_url, :file_processing, :file_file_size, 
                :file_content_type, :file_file_name, :mobile, :metadata]
            }
          }
        }
      }
    }
  end

  def self.update_observation_counts(options = {})
    scope = if options[:ancestor]
      if taxon = (options[:ancestor].is_a?(Taxon) ? options[:ancestor] : Taxon.find_by_id(options[:ancestor]))
        taxon.descendants
      end
    elsif options[:taxon_ids]
      taxa = Taxon.where("id IN (?)", options[:taxon_ids])
      options[:count_ancestors] ?
        Taxon.where("id IN (?)", taxa.map(&:self_and_ancestor_ids).flatten.uniq) : taxa
    elsif options[:scope]
      options[:scope]
    else
      Taxon.all
    end
    return if scope.count == 0
    scope = scope.select("id, ancestry")
    scope.select(:id).find_in_batches do |batch|
      taxon_ids = []
      batch.each do |t|
        Taxon.where(id: t.id).update_all(observations_count:
          Observation.elastic_search(
            filters: [ { term: { "taxon.ancestor_ids" => t.id } } ],
            size: 0,
            track_total_hits: true
          ).total_entries)
        taxon_ids << t.id
      end
      Taxon.elastic_index!( ids: taxon_ids )
    end
  end

  def self.index_taxa( taxa )
    taxon_ids = taxa.map{|t| t.is_a?( Taxon ) ? t.id : t}
    Taxon.elastic_index!( ids: taxon_ids )
  end

  # /Static #################################################################

end
