# CheckLists are lists of Taxa that occur in a Place.
class CheckList < List
  belongs_to :place
  belongs_to :taxon
  
  before_create :set_last_synced_at, :set_title, :create_taxon_list_rule
  after_save :update_listed_taxa_places
  
  validates_presence_of :place_id
  validates_uniqueness_of :taxon_id, :scope => :place_id, :allow_nil => true,
    :message => "already has a check list for this place."
  
  # TODO: the following should work through list rules
  # validates_uniqueness_of :taxon_id, :scope => :place_id
  
  def update_listed_taxa_places
    if self.place_id
      ListedTaxon.update_all("place_id = #{self.place_id}", "list_id = #{self.id}")
    end
  end
  
  # CheckLists can be edited by any logged in user.
  def editable_by?(user)
    user.is_a?(User)
  end
  
  def owner_name
    self.place.name
  end
  
  # Is this the default check list of its place?
  def is_default?
    self.place.check_list_id == self.id
  end
  
  def create_taxon_list_rule
    unless self.taxon.nil? || 
        self.rules.map(&:operand_id).include?(self.taxon_id)
      self.rules << ListRule.new(
        :operand => self.taxon, :operator => 'in_taxon?'
      )
    end
  end
  
  def set_title
    return true unless self.title.blank?
    unless self.taxon
      self.title = "#{self.place.name} Check List"
      return
    end
    common_name = self.taxon.common_name
    self.title = "#{common_name ? common_name.name : self.taxon.name} of " + 
      self.place.name
    true
  end
  
  def set_last_synced_at
    self.last_synced_at = Time.now
  end
  
  def sync_with_parent(options = {})
    conditions = "listed_taxa.place_id IS NOT NULL"
    unless options[:force]
      time_since_last_sync = options[:time_since_last_sync] || 1.hour.ago
      conditions = CheckList.merge_conditions(conditions, 
        ["listed_taxa.created_at > ?", time_since_last_sync])
    end
    return unless self.place.parent_id
    parent_check_list = self.place.parent.check_list
    self.listed_taxa.all(
      :include => [:taxon, {:place => {:parent => :check_list}}], 
      :conditions => conditions
    ).each do |listed_taxon|
      next if parent_check_list.listed_taxa.exists?(:taxon_id => listed_taxon.taxon_id)
      parent_check_list.add_taxon(listed_taxon.taxon)
    end
    parent_check_list.update_attribute(:last_synced_at, Time.now)
  end
  
  # TODO when we have real spatial queries, and maybe data quality grades
  def last_observation_of(taxon)
    nil
  end
  
  def self.sync_check_lists_with_parents(options = {})
    time_since_last_sync = options[:time_since_last_sync] || 1.hour.ago
    start_time = Time.now
    logger.info "[INFO] Starting CheckList.sync_check_lists_with_parents " + 
      "at #{start_time}..."

    ListedTaxon.all(
      :include => [:taxon, :list, {:place => {:parent => :check_list}}], 
      :conditions => [
        "listed_taxa.place_id IS NOT NULL AND listed_taxa.created_at > ?", 
        time_since_last_sync]
    ).each do |listed_taxon|
      next unless listed_taxon.place.parent_id
      parent_check_list = listed_taxon.place.parent.check_list
      next if parent_check_list.listed_taxa.exists?(:taxon_id => listed_taxon.taxon_id)
      parent_check_list.add_taxon(listed_taxon.taxon)
    end
    parent_check_list.update_attribute(:last_synced_at, Time.now)

    logger.info "[INFO] Finished CheckList.sync_check_lists_with_parents " + 
      "at #{Time.now} (#{Time.now - start_time}s)"
  end
end
