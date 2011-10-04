# CheckLists are lists of Taxa that occur in a Place.
class CheckList < List
  belongs_to :place
  belongs_to :taxon
  
  before_validation :set_title
  before_create :set_last_synced_at, :create_taxon_list_rule
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
    true
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
    unless taxon.nil? || rules.map(&:operand_id).include?(taxon_id)
      self.rules << ListRule.new(:operand => taxon, :operator => 'in_taxon?')
    end
    true
  end
  
  def set_title
    return true unless title.blank?
    unless taxon
      self.title = "#{place.name} Check List"
      return true
    end
    common_name = taxon.common_name
    self.title = "#{common_name ? common_name.name : taxon.name} of #{place.name}"
    true
  end
  
  def set_last_synced_at
    self.last_synced_at = Time.now
    true
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
  
  def first_observation_of(taxon)
    Observation.recently_added.of(taxon).in_place(place).
      has_quality_grade(Observation::RESEARCH_GRADE).last
  end
  
  def last_observation_of(taxon)
    Observation.of(taxon).in_place(place).has_quality_grade(Observation::RESEARCH_GRADE).latest.first
  end
  
  def observation_stats_for(taxon)
    Observation.in_place(place).has_quality_grade(Observation::RESEARCH_GRADE).
      of(taxon).count(:group => "EXTRACT(month FROM observed_on)")
  end
  
  # This is a loaded gun.  Please fire with discretion.
  def add_intersecting_taxa(options = {})
    return nil unless PlaceGeometry.exists?(["place_id = ?", place_id])
    ancestor = options[:ancestor].is_a?(Taxon) ? options[:ancestor] : Taxon.find_by_id(options[:ancestor])
    if options[:ancestor] && ancestor.blank?
      return nil
    end
    scope = Taxon.intersecting_place(place).scoped({})
    scope = scope.descendants_of(ancestor) if ancestor
    scope.find_each do |taxon|
      send_later(:add_taxon, taxon.id)
    end
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
  
  def self.refresh_with_observation(observation, options = {})
    start = Time.now
    Rails.logger.info "[INFO #{start}] Starting CheckList.refresh_with_observation for #{observation}, options: #{options.inspect}"
    # retrieve the observation or the id of the deleted observation and any relevant taxa
    if observation.is_a?(Observation)
      observation_id = observation.id
    else
      observation_id = observation.to_i
      observation = Observation.find_by_id(observation_id)
    end
    taxon_id = observation.try(:taxon_id) || options[:taxon_id]
    return if taxon_id.blank?
    taxon_ids = [taxon_id]
    taxon_ids += observation.taxon.ancestor_ids if observation
    
    # get places in which the observation was made
    place_ids = if observation && observation.georeferenced?
      conditions = if observation.coordinates_obscured?
        "ST_Intersects(place_geometries.geom, ST_Point(observations.private_longitude, observations.private_latitude))"
      else
        "ST_Intersects(place_geometries.geom, observations.geom)"
      end
      PlaceGeometry.all(:select => "place_geometries.id, place_id",
        :joins => "JOIN observations ON observations.id = #{observation_id}",
        :conditions => conditions).map(&:place_id)
    else
      []
    end
    place_ids.uniq!
    
    # get places places where this obs was made that already have this taxon listed
    existing_place_ids = ListedTaxon.all(:select => "id, list_id, place_id, taxon_id", 
      :conditions => ["place_id IN (?) AND taxon_id = ?", place_ids, taxon_id]).map(&:place_id)
    if observation
      confirmed_listed_taxa = ListedTaxon.all(:conditions => [
        "place_id IS NOT NULL AND last_observation_id = ?", observation.id])
      confirmed_place_ids = confirmed_listed_taxa.map(&:place_id)
      legit_confirmed_place_ids = confirmed_listed_taxa.select{|lt| place_ids.include?(lt.place_id)}.map(&:place_id)
      illegit_confirmed_place_ids = confirmed_place_ids - legit_confirmed_place_ids
      illegit_confirmed_listed_taxa = confirmed_listed_taxa.select{|lt| illegit_confirmed_place_ids.include?(lt.place_id)}
      existing_place_ids += legit_confirmed_place_ids
    else
      illegit_confirmed_listed_taxa = []
    end
    existing_place_ids.uniq!
      
    # if we need to add / update
    if observation && observation.quality_grade == Observation::RESEARCH_GRADE
      # rely on update_observation_associates callback on ListedTaxon to reset the assocs
      ListedTaxon.all(:conditions => ["place_id IN (?) AND taxon_id IN (?)", existing_place_ids, taxon_ids]).each do |lt|
        lt.force_update_observation_associates = true
        lt.save
      end
      return unless observation.taxon.rank == Taxon::SPECIES
      new_place_ids = place_ids - existing_place_ids
      CheckList.find_each(:joins => "JOIN places ON places.check_list_id = lists.id", 
          :conditions => ["place_id IN (?)", new_place_ids]) do |list|
        list.add_taxon(observation.taxon, :force_update_observation_associates => true)
      end
      
      # remove from illegit confirmed places
      illegit_confirmed_listed_taxa.each do |lt|
        obs = ListedTaxon.update_last_observation_for(lt)
        lt.destroy if obs.blank? && lt.can_be_auto_removed_from_check_list?
        obs = nil
      end
    
    # otherwise well be refreshing / deleting
    else
      conditions = ["place_id > 0 AND last_observation_id = ?", observation_id]
      ListedTaxon.find_each(:include => :list, :conditions => conditions) do |lt|
        obs = ListedTaxon.update_last_observation_for(lt)
        lt.destroy if obs.blank? && lt.can_be_auto_removed_from_check_list?
        obs = nil
      end
    end
    Rails.logger.info "[INFO #{Time.now}] Finished CheckList.refresh_with_observation for #{observation} (#{Time.now - start}s)"
  end
end
