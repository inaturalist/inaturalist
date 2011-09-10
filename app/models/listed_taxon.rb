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
  belongs_to :last_observation,
             :class_name => 'Observation', 
             :foreign_key => 'last_observation_id'
  belongs_to :place
  belongs_to :user
  belongs_to :updater, :class_name => 'User'
  has_many :comments, :as => :parent, :dependent => :destroy
  
  before_validation :nilify_blanks
  before_create :set_ancestor_taxon_ids
  before_create :set_place_id
  before_create :set_updater_id
  before_save :update_last_observation
  before_save :set_user_id
  after_create :update_user_life_list_taxa_count
  after_create :sync_parent_check_list
  after_create :delta_index_taxon
  after_destroy :update_user_life_list_taxa_count
  
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
      {:include => [:taxon], :order => "taxa.lft ASC"}
    else
      {} # default to id asc ordering
    end
  }
  
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
  
  attr_accessor :skip_update_last_observation
  
  def to_s
    "<ListedTaxon #{self.id}: taxon_id: #{self.taxon_id}, " + 
    "list_id: #{self.list_id}>"
  end
  
  def validate
    # don't bother if validates_presence_of(:taxon) has already failed
    if errors.on(:taxon).blank?
      self.list.rules.each do |rule|
        errors.add(taxon.to_plain_s, "is not #{rule.terms}") unless rule.validates?(self.taxon)
      end
    end
    
    if self.last_observation && self.taxon != self.last_observation.taxon
      errors.add(self.taxon.name, "must be the same as the last observed " + 
                                  "taxon, #{self.last_observation.taxon}")
    end
    
    unless list.is_a?(CheckList)
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
  def update_last_observation(options = {})
    return true if @skip_update_last_observation
    if list.is_a?(CheckList)
      ListedTaxon.send_later(:update_last_observation_for, id, options)
    end
    self.last_observation = options[:latest_observation] || list.last_observation_of(taxon_id)
    true
  end
  
  def self.update_last_observation_for(listed_taxon, options = {})
    listed_taxon = ListedTaxon.find_by_id(listed_taxon.to_i) unless listed_taxon.is_a?(ListedTaxon)
    return unless listed_taxon
    obs = options[:latest_observation] || listed_taxon.list.last_observation_of(listed_taxon.taxon_id)
    if listed_taxon.valid?
      ListedTaxon.update_all(["last_observation_id = ?", obs], ["id = ?", listed_taxon])
    else
      Rails.logger.error "[ERROR #{Time.now}] Failed to add #{obs} " + 
        "as last observation of #{listed_taxon}: #{listed_taxon.errors.full_messages.to_sentence}"
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
  
  def set_updater_id
    self.updater_id ||= user_id
    true
  end
  
  def set_place_id
    self.place_id = self.list.place_id
    true
  end
  
  def sync_parent_check_list
    return unless list.is_a?(CheckList)
    list.send_later(:sync_with_parent)
    true
  end
  
  def delta_index_taxon
    taxon.delta = true
    taxon.save
    true
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
end
