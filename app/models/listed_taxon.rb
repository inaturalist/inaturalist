#
# Join model for Lists and Taxa.  In addition to storing a reference to the
# last observed taxon (saving some db time), this model's validation makes
# sure a taxon passes all of a list's ListRules.
#
class ListedTaxon < ActiveRecord::Base  
  has_subscribers
  
  belongs_to :list
  belongs_to :taxon, :counter_cache => true
  belongs_to :first_observation,
             :class_name => 'Observation', 
             :foreign_key => 'first_observation_id'
  belongs_to :last_observation,
             :class_name => 'Observation', 
             :foreign_key => 'last_observation_id'
  belongs_to :user # creator
  
  belongs_to :updater, :class_name => 'User'
  has_many :comments, :as => :parent, :dependent => :destroy
  
  # check list assocs
  belongs_to :place
  belongs_to :taxon_range # if listed taxon was created b/c of a range intersection
  belongs_to :source # if added b/c of a published source
  
  before_validation :nilify_blanks
  before_validation :set_ancestor_taxon_ids
  before_validation :update_cache_columns
  before_create :set_place_id
  before_create :set_updater_id
  before_save :set_user_id
  before_save :set_source_id
  after_save :update_cache_columns_for_check_list
  after_commit :expire_caches
  after_create :update_user_life_list_taxa_count
  after_create :sync_parent_check_list
  after_create :delta_index_taxon
  before_destroy :set_old_list
  after_destroy :update_user_life_list_taxa_count
  after_destroy :expire_caches
  
  validates_presence_of :list_id, :taxon_id
  validates_uniqueness_of :taxon_id, 
                          :scope => :list_id, 
                          :message => "is already in this list"
  
  scope :by_user, lambda {|user| includes(:list).where("lists.user_id = ?", user)}
  
  scope :order_by, lambda {|order_by|
    case order_by
    when "alphabetical"
      includes(:taxon).order("taxa.name ASC")
    when "taxonomic"
      includes(:taxon).order("taxa.ancestry ASC, taxa.id ASC")
    else
      {} # default to id asc ordering
    end
  }
  
  scope :confirmed, where("last_observation_id IS NOT NULL")
  
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
  
  ESTABLISHMENT_MEANS = %w(native endemic introduced naturalised invasive managed)
  ESTABLISHMENT_MEANS_DESCRIPTIONS = ActiveSupport::OrderedHash.new
  ESTABLISHMENT_MEANS_DESCRIPTIONS["native"] = "evolved in this region or arrived by non-anthropogenic means"
  ESTABLISHMENT_MEANS_DESCRIPTIONS["endemic"] = "native and occurs nowhere else"
  ESTABLISHMENT_MEANS_DESCRIPTIONS["introduced"] = "arrived in the region via anthropogenic means"
  ESTABLISHMENT_MEANS_DESCRIPTIONS["naturalised"] = "reproduces naturally and forms part of the local ecology"
  ESTABLISHMENT_MEANS_DESCRIPTIONS["invasive"] = "has a deleterious impact on another organism, multiple organisms, or the ecosystem as a whole"
  ESTABLISHMENT_MEANS_DESCRIPTIONS["managed"] = "maintains presence through intentional cultivation or husbandry"
  
  ESTABLISHMENT_MEANS.each do |means|
    const_set means.upcase, means
    define_method "#{means}?" do
      establishment_means == means
    end
  end
  
  NATIVE_EQUIVALENTS = %w(native endemic)
  INTRODUCED_EQUIVALENTS = %w(introduced naturalised invasive managed)
  
  validates_inclusion_of :occurrence_status_level, :in => OCCURRENCE_STATUS_LEVELS.keys, :allow_blank => true
  validates_inclusion_of :establishment_means, :in => ESTABLISHMENT_MEANS, :allow_blank => true, :allow_nil => true
  validate :not_on_a_comprehensive_check_list, :on => :create
  validate :absent_only_if_not_confirming_observations
  validate :preserve_absense_if_not_on_a_comprehensive_list
  validate :list_rules_pass
  validate :taxon_matches_observation
  validate :check_list_editability
  
  CHECK_LIST_FIELDS = %w(place_id occurrence_status establishment_means)
  
  attr_accessor :skip_sync_with_parent,
                :skip_update_cache_columns,
                :force_update_cache_columns,
                :extra,
                :html,
                :old_list
  
  def ancestry
    taxon_ancestor_ids
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
      errors.add(:taxon_id, "isn't on the comprehensive list \"#{existing_comprehensive_list.title}\"")
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
    @existing_comprehensive_list = CheckList.first(:conditions => [
      "comprehensive = 't' AND id != ? AND taxon_id IN (?) AND place_id IN (?)", 
      list_id, taxon.ancestor_ids, places])
  end
  
  def existing_comprehensive_listed_taxon
    return nil unless existing_comprehensive_list
    @existing_listed_taxon ||= existing_comprehensive_list.listed_taxa.first(:conditions => ["taxon_id = ?", taxon_id])
  end
  
  def absent_only_if_not_confirming_observations
    return true unless occurrence_status_level_changed?
    return true unless absent?
    if first_observation || last_observation
      errors.add(:occurrence_status_level, "can't be absent if there are confirming observations")
    end
    true
  end
  
  def preserve_absense_if_not_on_a_comprehensive_list
    return true unless occurrence_status_level_changed?
    return true if absent?
    return true unless existing_comprehensive_list
    return true if existing_comprehensive_listed_taxon
    errors.add(:occurrence_status_level, "can't be changed from absent if this taxon is not on the comprehensive list of #{existing_comprehensive_list.taxon.name}")
    true
  end

  def list_rules_pass
    # don't bother if validates_presence_of(:taxon) has already failed
    if !errors.include?(:taxon) && taxon
      list.rules.each do |rule|
        errors.add(:base, "#{taxon.to_plain_s} is not #{rule.terms}") unless rule.validates?(taxon)
      end
    end
  end

  def taxon_matches_observation
    if last_observation && !(taxon_id == last_observation.taxon_id || taxon.ancestor_of?(last_observation.taxon) || last_observation.taxon.ancestor_of?(taxon))
      errors.add(:taxon_id, "must be the same as the last observed taxon, #{last_observation.taxon.try(:to_plain_s)}")
    end
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
  
  def set_ancestor_taxon_ids
    return true unless taxon
    unless taxon.ancestry.blank?
      self.taxon_ancestor_ids = taxon.ancestry
    else
      self.taxon_ancestor_ids = '' # this should probably be in the db...
    end
    true
  end

  def set_old_list
    @old_list = self.list
  end
  
  # Update the counter cache in users.
  def update_user_life_list_taxa_count
    l = self.list || @old_list
    if l && l.user && l.user.life_list_id == self.list_id
      User.update_all("life_list_taxa_count = #{l.listed_taxa.count}", "id = #{l.user_id}")
    end
    true
  end
  
  def set_user_id
    self.user_id ||= list.user_id
    true
  end
  
  def set_source_id
    self.source_id ||= list.source_id
    true
  end
  
  def set_updater_id
    self.updater_id ||= user_id
    true
  end
  
  def set_place_id
    self.place_id = self.list.place_id
    true
  end
  
  def sync_parent_check_list
    return true unless list.is_a?(CheckList)
    return true if @skip_sync_with_parent
    unless Delayed::Job.exists?(["handler LIKE E'%CheckList;?\n%sync_with_parent%'", list_id])
      list.delay(:priority => INTEGRITY_PRIORITY).sync_with_parent
    end
    true
  end
  
  def delta_index_taxon
    Taxon.update_all(["delta = ?", true], ["id = ?", taxon_id])
    true
  end
  
  def update_cache_columns
    return true if @skip_update_cache_columns
    return true if list.is_a?(CheckList) && (!@force_update_cache_columns || place_id.blank?)
    set_cache_columns
    true
  end
  
  def set_cache_columns
    return unless taxon_id
    self.first_observation_id, self.last_observation_id, self.observations_count, self.observations_month_counts = cache_columns
  end
  
  def update_cache_columns_for_check_list
    return true if @skip_update_cache_columns
    return true unless list.is_a?(CheckList)
    if @force_update_cache_columns
      # this should have already happened in update_cache_columns
    else
      ListedTaxon.delay(:priority => INTEGRITY_PRIORITY).update_cache_columns_for(id)
    end
    true
  end
  
  def cache_columns
    return unless (sql = list.cache_columns_query_for(self))
    ids = []
    counts = {}
    connection.execute(sql.gsub(/\s+/, ' ').strip).each do |row|
      counts[row['key']] = row['count'].to_i
      ids += row['ids'].to_s.gsub(/[\{\}]/, '').split(',')
    end
    ids = ids.map {|id| id == "NULL" ? nil : id.to_i}.compact.uniq
    first_observation_id = nil
    last_observation_id = nil
    unless ids.blank?
      first_observation_id = ids.min
      last_observation_id = Observation.latest.first(
        :select => "id, observed_on, time_observed_at", 
        :conditions => ["id IN (?)", ids]
      ).try(:id)
    end
    total = counts.map{|k,v| v}.sum
    month_counts = counts.map{|k,v| k ? "#{k}-#{v}" : nil}.compact.sort.join(',')
    [first_observation_id, last_observation_id, total, month_counts]
  end
  
  def self.update_cache_columns_for(lt)
    lt = ListedTaxon.find_by_id(lt) unless lt.is_a?(ListedTaxon)
    return nil unless lt
    lt.set_cache_columns
    update_all(
      ["first_observation_id = ?, last_observation_id = ?, observations_count = ?, observations_month_counts = ?", 
        lt.first_observation_id, lt.last_observation_id, lt.observations_count, lt.observations_month_counts],
      ["id = ?", lt.id]
    )
  end
  
  def observation_month_stats
    return {} if observations_month_counts.blank?
    r_stats = confirmed_observation_month_stats
    c_stats = casual_observation_month_stats
    stats = {}
    (r_stats.keys + c_stats.keys).uniq.each do |key|
      stats[key] = r_stats[key].to_i + c_stats[key].to_i
    end
    stats
  end
  
  def confirmed_observation_month_stats
    return {} if observations_month_counts.blank?
    Hash[observations_month_counts.split(',').map {|kv| 
      k, v = kv.split('-')
      quality_grade = k[/[rc]/,0]
      next unless (quality_grade == 'r' || quality_grade.blank?)
      [k.to_i.to_s, v.to_i]
    }.compact]
  end
  
  def casual_observation_month_stats
    return {} if observations_month_counts.blank?
    Hash[observations_month_counts.split(',').map {|kv| 
      k, v = kv.split('-')
      quality_grade = k[/[rc]/,0]
      next unless quality_grade == 'c'
      [k.to_i.to_s, v.to_i]
    }.compact]
  end
  
  def confirmed_observations_count
    confirmed_observation_month_stats.map{|k,v| v}.sum
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
      list.is_default?
  end
  
  def introduced?
    INTRODUCED_EQUIVALENTS.include?(establishment_means)
  end
  
  def native?
    NATIVE_EQIVALENTS.include?(establishment_means)
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
  
  # Update the taxon_ancestors of ALL listed_taxa. Note this will be
  # slow and memory intensive, so it should only be run from a script.
  def self.update_all_taxon_attributes
    start_time = Time.now
    Rails.logger.info "[INFO] Starting ListedTaxon.update_all_taxon_attributes..."
    Taxon.do_in_batches(:conditions => "listed_taxa_count IS NOT NULL") do |taxon|
      taxon.update_listed_taxa
    end
    Rails.logger.info "[INFO] Finished ListedTaxon.update_all_taxon_attributes " +
      "(#{Time.now - start_time}s)"
  end
  
  def guide_taxon_cache_key
    "guide_taxon_#{id}_#{taxon_id}"
  end
  
  def expire_caches
    return true unless place_id
    ctrl = ActionController::Base.new
    ctrl.expire_fragment(guide_taxon_cache_key) #THIS
    ctrl.expire_page("/places/cached_guide/#{place_id}.html")
    true
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
  
  def self.merge_duplicates(options = {})
    where = options.map{|k,v| "#{k} = #{v}"}.join(' AND ') unless options.blank?
    sql = <<-SQL
      SELECT list_id, taxon_id, array_agg(id) AS ids, count(*) 
      FROM listed_taxa
      #{"WHERE #{where}" if where}
      GROUP BY list_id, taxon_id HAVING count(*) > 1
    SQL
    connection.execute(sql.gsub(/\s+/, ' ').strip).each do |row|
      to_merge_ids = row['ids'].to_s.gsub(/[\{\}]/, '').split(',').sort
      lt = ListedTaxon.find_by_id(to_merge_ids.first)
      rejects = ListedTaxon.all(:conditions => ["id IN (?)", to_merge_ids[1..-1]])
      rejects.each do |reject|
        lt.merge(reject)
      end
    end
  end

  def self.update_for_taxon_change(taxon_change, taxon, options = {})
    input_taxon_ids = taxon_change.input_taxa.map(&:id)
    scope = ListedTaxon.where("listed_taxa.taxon_id IN (?)", input_taxon_ids).scoped
    scope = scope.where(:user_id => options[:user]) if options[:user]
    scope = scope.where("listed_taxa.id IN (?)", options[:records]) unless options[:records].blank?
    scope = scope.where(options[:conditions]) if options[:conditions]
    scope = scope.includes(options[:include]) if options[:include]
    scope.find_each do |lt|
      lt.force_update_cache_columns = true
      lt.update_attributes(:taxon => taxon)
      yield(lt) if block_given?
    end
  end
  
end
