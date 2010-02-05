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
  
  before_create :set_ancestor_taxon_ids
  before_create :set_place_id
  before_save :set_lft
  before_create :update_last_observation
  after_create :update_user_life_list_taxa_count
  after_create :sync_parent_check_list
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
  
  def to_s
    "<ListedTaxon #{self.id}: taxon_id: #{self.taxon_id}, " + 
    "list_id: #{self.list_id}>"
  end
  
  def user
    list.user
  end
  
  def user_id
    list.user_id
  end
  
  def validate
    self.list.rules.each do |rule|
      unless rule.validates?(self.taxon)
        errors.add(taxon.to_plain_s, "is not #{rule.terms}")
      end
    end
    
    if self.last_observation && self.taxon != self.last_observation.taxon
      errors.add(self.taxon.name, "must be the same as the last observed " + 
                                  "taxon, #{self.last_observation.taxon}")
    end
  end
  
  #
  # Update the last observation for this listed_taxon.  This might have worked
  # in a validation, but it involves a potentially expensive query, so it's
  # here.  Takes an optional last_observation if one had been chosen in the
  # calling scope to save a query.
  #
  def update_last_observation(latest_observation = nil)
    return if self.place_id || self.list.is_a?(CheckList)
    
    latest_observation ||= Observation.latest.by(
      self.list.user).find(:first, :conditions => ["taxon_id = ?", self.taxon])
    if self.last_observation != latest_observation
      self.last_observation = latest_observation
    end
    self
  end
  
  def set_lft
    self.lft = self.taxon.lft
  end
  
  def set_ancestor_taxon_ids
    ancestors = self.taxon.ancestors.all(:select => 'id')
    unless ancestors.blank?
      self.taxon_ancestor_ids = ancestors.map(&:id).join(',') 
    else
      self.taxon_ancestor_ids = '' # this should probably be in the db...
    end
  end
  
  # Update the counter cache in users.
  def update_user_life_list_taxa_count
    if self.list.user && self.list.user.life_list_id == self.list_id
      User.update_all("life_list_taxa_count = #{self.list.listed_taxa.count}", 
        "id = #{self.list.user_id}")
    end
  end
  
  def set_place_id
    self.place_id = self.list.place_id
  end
  
  def sync_parent_check_list
    return unless list.is_a?(CheckList)
    list.send_later(:sync_with_parent)
  end
  
  # Update the lft and taxon_ancestors of ALL listed_taxa. Note this will be
  # slow and memory intensive, so it should only be run from a script.
  def self.update_all_taxon_attributes
    start_time = Time.now
    logger.info "[INFO] Starting ListedTaxon.update_all_taxon_attributes..."
    Taxon.do_in_batches(:conditions => "listed_taxa_count > 0") do |taxon|
      taxon.update_listed_taxa
    end
    logger.info "[INFO] Finished ListedTaxon.update_all_taxon_attributes " +
      "(#{Time.now - start_time}s)"
  end
end
