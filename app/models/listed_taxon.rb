#
# Join model for Lists and Taxa.  In addition to storing a reference to the
# last observed taxon (saving some db time), this model's validation makes
# sure a taxon passes all of a list's ListRules.
#
class ListedTaxon < ActiveRecord::Base
  acts_as_activity_streamable :batch_window => 30.minutes, 
    :batch_partial => "lists/listed_taxa_activity_stream_batch",
    :user_scope => :by_user
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
  before_create :set_ancestor_taxon_ids
  before_create :set_place_id
  before_create :set_updater_id
  before_save :set_user_id
  before_save :set_source_id
  before_save :update_observation_associates
  after_save :update_observation_associates_for_check_list
  after_save :update_observations_count
  after_save :expire_caches
  after_create :update_user_life_list_taxa_count
  after_create :sync_parent_check_list
  after_create :delta_index_taxon
  after_destroy :update_user_life_list_taxa_count
  after_destroy :expire_caches
  
  validates_presence_of :list, :taxon
  validates_uniqueness_of :taxon_id, 
                          :scope => :list_id, 
                          :message => "is already in this list"
  
  named_scope :by_user, lambda {|user| 
    {:include => :list, :conditions => ["lists.user_id = ?", user]}
  }
  
  named_scope :order_by, lambda {|order_by|
    case order_by
    when "alphabetical"
      {:include => [:taxon], :order => "taxa.name ASC"}
    when "taxonomic"
      {:include => [:taxon], :order => "taxa.ancestry ASC, taxa.id ASC"}
    else
      {} # default to id asc ordering
    end
  }
  
  named_scope :confirmed, :conditions => "last_observation_id IS NOT NULL"
  
  ALPHABETICAL_ORDER = "alphabetical"
  TAXONOMIC_ORDER = "taxonomic"
  ORDERS = [ALPHABETICAL_ORDER, TAXONOMIC_ORDER]
  OCCURRENCE_STATUS_LEVELS = {
    60 => "present",
    # 50 => "common",
    # 40 => "uncommon",
    # 30 => "irregular",
    # 20 => "doubtful",
    10 => "absent"
  }
  OCCURRENCE_STATUSES = OCCURRENCE_STATUS_LEVELS.values
  OCCURRENCE_STATUS_DESCRIPTIONS = ActiveSupport::OrderedHash.new
  OCCURRENCE_STATUS_DESCRIPTIONS["present" ] =  "occurs in the area"
  # OCCURRENCE_STATUS_DESCRIPTIONS["common" ] =  "occurs frequently"
  # OCCURRENCE_STATUS_DESCRIPTIONS["uncommon" ] =  "occurs regularly, but in small numbers; requires careful searching of proper habitat" 
  # OCCURRENCE_STATUS_DESCRIPTIONS["irregular" ] =  "presence unpredictable, including vagrants; may be common in some years and absent others"
  # OCCURRENCE_STATUS_DESCRIPTIONS["doubtful" ] =  "presumed to occur, but doubt exists over the evidence"
  OCCURRENCE_STATUS_DESCRIPTIONS["absent" ] =  "does not occur in the area"
  
  ESTABLISHMENT_MEANS = %w(native introduced naturalised invasive managed)
  ESTABLISHMENT_MEANS_DESCRIPTIONS = ActiveSupport::OrderedHash.new
  ESTABLISHMENT_MEANS_DESCRIPTIONS["native"] = "evolved in this region or arrived by non-anthropogenic means"
  ESTABLISHMENT_MEANS_DESCRIPTIONS["introduced"] = "arrived in the region via anthropogenicmeans"
  ESTABLISHMENT_MEANS_DESCRIPTIONS["naturalised"] = "reproduces naturally and forms part of the local ecology"
  ESTABLISHMENT_MEANS_DESCRIPTIONS["invasive"] = "has a deleterious impact on another organism, multiple organisms, or the ecosystem as a whole"
  ESTABLISHMENT_MEANS_DESCRIPTIONS["managed"] = "maintains presence through intentional cultivation or husbandry"
  
  validates_inclusion_of :occurrence_status_level, :in => OCCURRENCE_STATUS_LEVELS.keys, :allow_blank => true
  validates_inclusion_of :establishment_means, :in => ESTABLISHMENT_MEANS, :allow_blank => true, :allow_nil => true
  
  CHECK_LIST_FIELDS = %w(place_id occurrence_status establishment_means)
  
  attr_accessor :skip_update_observation_associates,
                :skip_update_observations_count,
                :force_update_observation_associates,
                :skip_sync_with_parent
  
  def to_s
    "<ListedTaxon #{self.id}: taxon_id: #{self.taxon_id}, " + 
    "list_id: #{self.list_id}>"
  end
  
  def validate
    # don't bother if validates_presence_of(:taxon) has already failed
    if errors.on(:taxon).blank?
      list.rules.each do |rule|
        errors.add(taxon.to_plain_s, "is not #{rule.terms}") unless rule.validates?(taxon)
      end
    end
    
    if last_observation && !(taxon == last_observation.taxon || last_observation.taxon.in_taxon?(taxon))
      errors.add(:taxon_id, "must be the same as the last observed taxon, #{last_observation.taxon.try(:to_plain_s)}")
    end
    
    if list.is_a?(CheckList)
      if list.user && user && user != list.user && !user.is_curator?
        errors.add(:user_id, "must be the list creator or a curator")
      end
    else
      CHECK_LIST_FIELDS.each do |field|
        errors.add(field, "can only be set for check lists") unless send(field).blank?
      end
    end
  end
  
  #
  # Update the last observation for this listed_taxon.  This might have worked
  # in a validation, but it involves a potentially expensive query, so it's
  # here.  Takes an optional last_observation if one had been chosen in the
  # calling scope to save a query.
  #
  def update_observation_associates(options = {})
    return true if @skip_update_observation_associates
    return true if list.is_a?(CheckList)
    self.first_observation    = list.first_observation_of(taxon_id)
    self.last_observation     = list.last_observation_of(taxon_id)
    true
  end
  
  def update_observation_associates_for_check_list(options = {})
    return true if @skip_update_observation_associates
    return true unless list.is_a?(CheckList)
    if @force_update_observation_associates
      options = options.merge(:skip_save => true)
      @skip_update_observation_associates = true
      ListedTaxon.update_last_observation_for(self, options)
      ListedTaxon.update_first_observation_for(self, options)
      save
    else
      options[:dj_priority] = 1
      ListedTaxon.send_later(:update_last_observation_for, id, options)
      ListedTaxon.send_later(:update_first_observation_for, id, options)
    end
    return true
  end
  
  def self.update_first_observation_for(listed_taxon, options = {})
    update_observation_associate_for(listed_taxon, :first_observation, options)
  end
  
  def self.update_last_observation_for(listed_taxon, options = {})
    update_observation_associate_for(listed_taxon, :last_observation, options)
  end
  
  def self.update_observation_associate_for(listed_taxon, assoc_name, options = {})
    listed_taxon = ListedTaxon.find_by_id(listed_taxon.to_i) unless listed_taxon.is_a?(ListedTaxon)
    return unless listed_taxon
    list = listed_taxon.list
    obs = options[:observation] || list.send("#{assoc_name}_of", listed_taxon.taxon_id)
    listed_taxon.send("#{assoc_name}=", obs)
    yield(listed_taxon) if block_given?
    unless options[:skip_save]
      listed_taxon.skip_update_observation_associates = true
      unless listed_taxon.save
        Rails.logger.error "[ERROR #{Time.now}] Failed to add #{obs} " + 
          "as #{assoc_name} of #{listed_taxon}: #{listed_taxon.errors.full_messages.to_sentence}"
      end
    end
    obs
  end
  
  def set_ancestor_taxon_ids
    unless taxon.ancestry.blank?
      self.taxon_ancestor_ids = taxon.ancestor_ids.join(',') 
    else
      self.taxon_ancestor_ids = '' # this should probably be in the db...
    end
    true
  end
  
  # Update the counter cache in users.
  def update_user_life_list_taxa_count
    if self.list.user && self.list.user.life_list_id == self.list_id
      User.update_all("life_list_taxa_count = #{self.list.listed_taxa.count}", 
        "id = #{self.list.user_id}")
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
      list.send_later(:sync_with_parent, :dj_priority => 1)
    end
    true
  end
  
  def delta_index_taxon
    taxon.delta = true
    taxon.save
    true
  end
  
  def update_observations_count
    return true if @skip_update_observations_count
    if list.is_a?(CheckList) && !@force_update_observation_associates
      ListedTaxon.send_later(:update_observations_count_for, id, :dj_priority => 1)
      return true
    end
    ListedTaxon.update_observations_count_for(id)
    true
  end
  
  def self.update_observations_count_for(id)
    return true unless (lt = find_by_id(id))
    return true unless (counts = lt.list.observation_stats_for(lt.taxon_id))
    total_count = counts.map(&:last).sum
    month_counts = counts.map{|k,v| k ? "#{k}-#{v}" : nil}.compact.sort.join(',')
    ListedTaxon.update_all(
      ["observations_count = ?, observations_month_counts = ?", total_count, month_counts],
      ["id = ?", id]
    )
    true
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
  
  def editable_by?(user)
    list.editable_by?(user)
  end
  
  def removable_by?(user)
    return false unless user
    return true if user.admin?
    citation_object == user
  end
  
  def citation_object
    user || source || taxon_range || first_observation || last_observation
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
  
  # Update the taxon_ancestors of ALL listed_taxa. Note this will be
  # slow and memory intensive, so it should only be run from a script.
  def self.update_all_taxon_attributes
    start_time = Time.now
    logger.info "[INFO] Starting ListedTaxon.update_all_taxon_attributes..."
    Taxon.do_in_batches(:conditions => "listed_taxa_count IS NOT NULL") do |taxon|
      taxon.update_listed_taxa
    end
    logger.info "[INFO] Finished ListedTaxon.update_all_taxon_attributes " +
      "(#{Time.now - start_time}s)"
  end
  
  def guide_taxon_cache_key
    "guide_taxon_#{id}_#{taxon_id}"
  end
  
  def expire_caches
    return true unless place_id
    ctrl = ActionController::Base.new
    ctrl.expire_fragment(guide_taxon_cache_key)
    ctrl.expire_page("/places/cached_guide/#{place_id}.html")
    true
  end
  
end
