#encoding: utf-8
class Taxon < ActiveRecord::Base
  # Sometimes you don't want to make a new taxon name with a taxon, like when
  # you're saving a new taxon name with a new associated taxon. Hence, this.
  attr_accessor :skip_new_taxon_name
  
  # If you want to shove some HTML in there before creating some JSON...
  attr_accessor :html
  
  # Allow this taxon to be grafted to locked subtrees
  attr_accessor :skip_locks

  # Skip the more onerous callbacks that happen after grafting a taxon somewhere else
  attr_accessor :skip_after_move

  attr_accessor :locale

  # set this when you want methods to respond with user-specific content
  attr_accessor :current_user

  include ActsAsElasticModel

  acts_as_flaggable
  has_ancestry

  has_many :child_taxa, :class_name => Taxon.to_s, :foreign_key => :parent_id
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
  has_one :atlas, :inverse_of => :taxon
  belongs_to :source
  belongs_to :iconic_taxon, :class_name => 'Taxon', :foreign_key => 'iconic_taxon_id'
  belongs_to :creator, :class_name => 'User'
  belongs_to :updater, :class_name => 'User'
  belongs_to :conservation_status_source, :class_name => "Source"
  has_and_belongs_to_many :colors, -> { uniq }
  has_many :taxon_descriptions, :dependent => :destroy
  
  accepts_nested_attributes_for :conservation_status_source
  accepts_nested_attributes_for :source
  accepts_nested_attributes_for :conservation_statuses, :reject_if => :all_blank, :allow_destroy => true
  accepts_nested_attributes_for :taxon_photos, :allow_destroy => true

  before_validation :normalize_rank, :set_rank_level, :remove_rank_from_name
  before_save :set_iconic_taxon, # if after, it would require an extra save
              :capitalize_name
  after_save :create_matching_taxon_name,
             :set_wikipedia_summary_later,
             :handle_after_move
  after_commit :index_observations

  validates_presence_of :name, :rank
  validates_uniqueness_of :name, 
                          :scope => [:ancestry, :is_active],
                          :unless => Proc.new { |taxon| (taxon.ancestry.blank? || !taxon.is_active)},
                          :message => "already used as a child of this taxon's parent"
  # validates_uniqueness_of :source_identifier,
  #                         :scope => [:source_id],
  #                         :message => "already exists",
  #                         :allow_blank => true

  has_subscribers :to => {
    :observations => {:notification => "new_observations", :include_owner => false}
  }
  
  NAME_PROVIDER_TITLES = {
    'ColNameProvider' => 'Catalogue of Life',
    'NZORNameProvider' => 'New Zealand Organisms Register',
    'UBioNameProvider' => 'uBio'
  }
  
  RANK_LEVELS = {
    'root'         => 100,
    'kingdom'      => 70,
    'phylum'       => 60,
    'subphylum'    => 57,
    'superclass'   => 53,
    'class'        => 50,
    'subclass'     => 47,
    'superorder'   => 43,
    'order'        => 40,
    'suborder'     => 37,
    'infraorder'   => 35,
    'superfamily'  => 33,
    'epifamily'    => 32,
    'family'       => 30,
    'subfamily'    => 27,
    'supertribe'   => 26,
    'tribe'        => 25,
    'subtribe'     => 24,
    'genus'        => 20,
    'genushybrid'  => 20,
    'species'      => 10,
    'hybrid'       => 10,
    'subspecies'   => 5,
    'variety'      => 5,
    'form'         => 5
  }
  RANK_LEVELS.each do |rank, level|
    const_set rank.upcase, rank
    const_set "#{rank.upcase}_LEVEL", level
    define_method "find_#{rank}" do
      return self if rank_level == level
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
  
  RANKS = RANK_LEVELS.keys
  VISIBLE_RANKS = RANKS - ['root']
  
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
    'fo'              => 'form',
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
  
  PROBLEM_NAMES = ['california', 'lichen', 'bee hive', 'virginia', 'oman', 'winged insect', 
    'lizard', 'gall', 'pinecone', 'larva', 'cicada', 'caterpillar', 'caterpillars', 'chiton', 
    'arizona']
  
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
  
  scope :colored, lambda {|colors|
    colors = [colors] unless colors.is_a?(Array)
    if colors.first.to_i == 0
      joins(:colors).where("colors.value IN (?)", colors)
    else
      joins(:colors).where("colors.id IN (?)", colors)
    end
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
  
  def handle_after_move
    return true unless ancestry_changed?
    set_iconic_taxon
    return true if id_changed?
    return true if skip_after_move
    update_life_lists
    update_obs_iconic_taxa
    conditions = ["taxa.id = ? OR taxa.ancestry = ? OR taxa.ancestry LIKE ?", id, "#{ancestry}/#{id}", "#{ancestry}/#{id}/%"]
    old_conditions = ["taxa.id = ? OR taxa.ancestry = ? OR taxa.ancestry LIKE ?", id, ancestry_was, "#{ancestry_was}/#{id}/%"]
    if (Observation.joins(:taxon).where(conditions).exists? || 
        Observation.joins(:taxon).where(old_conditions).exists? || 
        Identification.joins(:taxon).where(conditions).exists? || 
        Identification.joins(:taxon).where(old_conditions).exists? )
      Observation.delay(priority: INTEGRITY_PRIORITY, queue: "slow",
        unique_hash: { "Observation::update_stats_for_observations_of": id }).
        update_stats_for_observations_of(id)
    end
    elastic_index!
    Taxon.refresh_es_index
    true
  end

  def index_observations
    Observation.elastic_index!(scope: observations.select(:id), delay: true)
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
    s = t.conservation_statuses.where("place_id IS NULL").map(&:iucn).max
    Taxon.where(id: t).update_all(conservation_status: s)
  end
  
  def capitalize_name
    self.name = if genus? && name =~ /^(x|×)\s+?(.+)/
      match, x, genus_name = name.match(/^(x|×)\s+?(.+)/).to_a
      "#{x} #{genus_name.capitalize}"
    else
      name.capitalize
    end
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
      if parent && rank_level && parent.rank_level && parent.rank_level > rank_level
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
  
  def move_to_child_of(taxon)
    update_attributes(:parent => taxon)
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
    return unless photo = obs.observation_photos.sort_by(&:position).first.try(:photo)
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
      chosen_taxon_photos = taxon_photos.includes(:photo).
        order("taxon_photos.position ASC NULLS LAST, taxon_photos.id ASC").
        limit(options[:limit])
    end
    if chosen_taxon_photos.size < options[:limit]
      descendant_taxon_photos = TaxonPhoto.joins(:taxon).includes(:photo).
        order("taxon_photos.id ASC").
        limit(options[:limit] - chosen_taxon_photos.size).
        where("taxa.ancestry LIKE '#{ancestry}/#{id}%'").
        where("taxon_photos.id NOT IN (?)", chosen_taxon_photos.map(&:id))
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
  
  validate :taxon_cant_be_its_own_ancestor
  validate :can_only_be_featured_if_photos
  validate :validate_locked

  def taxon_cant_be_its_own_ancestor
    if ancestor_ids.include?(id)
      errors.add(self.name, "can't be its own ancestor")
    end
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

  def update_life_lists(options = {})
    ids = options[:skip_ancestors] ? [id] : [id, ancestor_ids].flatten.compact
    if ListRule.exists?([
        "operator LIKE 'in_taxon%' AND operand_type = ? AND operand_id IN (?)", 
        Taxon.to_s, ids])
      LifeList.delay(priority: INTEGRITY_PRIORITY,
        unique_hash: { "LifeList::update_life_lists_for_taxon": id }).
        update_life_lists_for_taxon(self)
    end
    true
  end
  
  def update_obs_iconic_taxa
    Observation.where(taxon_id: id).update_all(iconic_taxon_id: iconic_taxon_id)
    true
  end
  
  def lsid
    "lsid:#{URI.parse(CONFIG.site_url).host}:taxa:#{id}"
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
  
  def wikipedia_summary(options = {})
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
  
  def set_wikipedia_summary(options = {})
    locale = options[:locale] || I18n.locale
    w = options[:wikipedia] || WikipediaService.new(:locale => locale)
    wname = wikipedia_title.blank? ? name : wikipedia_title
    
    if summary = w.summary(wname, options)
      pre_trunc = summary
      summary = summary.split[0..75].join(' ')
      summary += '...' if pre_trunc > summary
    end
    
    if locale.to_s =~ /^en-?/
      if summary.blank?
        Taxon.where(id: self).update_all(wikipedia_summary: Date.today)
        return nil
      else
        Taxon.where(id: self).update_all(wikipedia_summary: summary)
      end
    else
      td = taxon_descriptions.where(:locale => locale).first
      td ||= self.taxon_descriptions.build(:locale => locale)
      if td
        td.update_attributes(:body => summary)
      end
    end
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
      unless taxon_name.valid?
        Rails.logger.info "[INFO] Destroying #{taxon_name} while merging taxon " + 
          "#{reject.id} into taxon #{id}: #{taxon_name.errors.full_messages.to_sentence}"
        taxon_name.destroy 
        next
      end
      if taxon_name.is_scientific_names? && taxon_name.is_valid?
        taxon_name.update_attributes(:is_valid => false)
      end
    end
    
    LifeList.delay(:priority => INTEGRITY_PRIORITY).update_life_lists_for_taxon(self)
    
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
    if association(:listed_taxa_with_establishment_means).loaded? || association(:listed_taxa).loaded?
      lt = association(:listed_taxa_with_establishment_means).loaded? ?
        listed_taxa_with_establishment_means : listed_taxa
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
    else
      listed_taxa.with_establishment_means(means).where(place_id: places).exists?
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
    target_taxon_ids = [
      taxon_ids,
      Taxon.where( "id IN (?)", taxon_ids).pluck(:ancestry).map{|a| a.to_s.split( "/" ).map(&:to_i)}
    ].flatten.compact.uniq
    global_status = ConservationStatus.where("place_id IS NULL AND taxon_id IN (?)", target_taxon_ids).order("iucn ASC").last
    if global_status && global_status.geoprivacy == Observation::PRIVATE
      return global_status.geoprivacy
    end
    geoprivacies = [ global_status.try(:geoprivacy) ]
    geoprivacies += ConservationStatus.
      where( "taxon_id IN (?)", target_taxon_ids ).
      for_lat_lon( options[:latitude], options[:longitude] ).pluck( :geoprivacy )
    geoprivacies = geoprivacies.uniq.reject{ |gp| gp.blank? || gp == Observation::OPEN }
    return geoprivacies.first if geoprivacies.size == 1
    return Observation::PRIVATE if geoprivacies.include?( Observation::PRIVATE )
    return Observation::OBSCURED unless geoprivacies.blank?
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
          t.update_life_lists(:skip_ancestors => true)
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

  def taxon_ranges_with_kml
    taxon_ranges = self.taxon_ranges.without_geom.includes(:source).limit(10).select(&:kml_url)
    taxon_range = if CONFIG.taxon_range_source_id
      taxon_ranges.detect{|tr| tr.source_id == CONFIG.taxon_range_source_id}
    end
    taxon_range ||= taxon_ranges.detect{|tr| !tr.range.blank?}
    [taxon_range, taxon_ranges - [taxon_range]].flatten
  end

  def all_names
    taxon_names.map(&:name)
  end

  def self.import(name, options = {})
    name = normalize_name(name)
    ancestor = options.delete(:ancestor)
    external_names = begin
      ratatosk.find(name)
    rescue Timeout::Error => e
      []
    end
    external_names.select!{|en| en.name.downcase == name.downcase} if options[:exact]
    return nil if external_names.blank?
    external_names.each do |en| 
      if en.save && !en.taxon.grafted? && en.taxon.persisted?
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
    return false if taxon_changes.exists? || taxon_change_taxa.exists?
    creator_id == user.id
  end

  def match_descendants(taxon_hash)
    Taxon.match_descendants_of_id(id, taxon_hash)
  end

  # get the extreme's of this taxon's observations as determined
  # by our cache table for grids, at the highest zoom
  def bounds
    return @bounds if defined?(@bounds)
    result = Taxon.connection.execute("SELECT
      MIN(ST_YMIN(geom)) min_y, MAX(ST_YMAX(geom)) max_y,
      MIN(ST_XMIN(geom)) min_x, MAX(ST_XMAX(geom)) max_x
      FROM observation_zooms_2 WHERE taxon_id=#{ id }").first
    @bounds = result['min_x'].nil? ?
      { } :
      {
        min_x: [result['min_x'].to_f, -179.9].max,
        min_y: [result['min_y'].to_f, -89.9].max,
        max_x: [result['max_x'].to_f, 179.9].min,
        max_y: [result['max_y'].to_f, 89.9].min
      }
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
    scope = scope.where(:lexicon => options[:lexicon]) if options[:lexicon]
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
    taxon_names = taxon_names.compact.sort do |tn1,tn2|
      tn1_exact = names.include?(tn1.name) ? 1 : 0
      tn2_exact = names.include?(tn2.name) ? 1 : 0
      [tn2_exact, tn2.name.size] <=> [tn1_exact, tn1.name.size]
    end
    taxon_names.map{|tn| tn.taxon}.compact
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

    # if the names are synonymous and share the same parent, choose the first active concept
    elsif taxon_names.map(&:name).uniq.size == 1 && taxa.map(&:parent_id).uniq.size == 1
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
      Taxon.where("id IN (?)", taxa.map(&:self_and_ancestor_ids).flatten.uniq)
    elsif options[:scope]
      options[:scope]
    else
      Taxon.all
    end
    return if scope.count == 0
    scope = scope.select("id, ancestry")
    scope.find_each do |t|
      Taxon.where(id: t.id).update_all(observations_count:
        Observation.elastic_search(
          where: { "taxon.ancestor_ids" => t.id }, size: 0).total_entries)
    end
  end

  def self.refresh_es_index
    Taxon.__elasticsearch__.refresh_index! unless Rails.env.test?
  end

  # /Static #################################################################

end
