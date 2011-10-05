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
    observation, observation_id = get_observation_to_refresh(observation)
    options[:observation_id] ||= observation_id
    taxon_ids = get_taxon_ids_to_refresh(observation, options)
    return if taxon_ids.blank?
    current_place_ids = get_current_place_ids_to_refresh(observation, options)
    current_listed_taxa = ListedTaxon.all(:conditions => ["place_id IN (?) AND taxon_id IN (?)", current_place_ids, taxon_ids])
    new_place_ids = current_place_ids - current_listed_taxa.map(&:place_id)
    old_place_ids = get_old_place_ids_to_refresh(observation, options)
    old_listed_taxa = ListedTaxon.all(:conditions => ["place_id IN (?) AND taxon_id IN (?)", old_place_ids - current_place_ids, taxon_ids])
    listed_taxa = (current_listed_taxa + old_listed_taxa).compact.uniq
    unless listed_taxa.blank?
      listed_taxa.each do |lt|
        lt.force_update_observation_associates = true
        lt.save # sets all observation associates, months stats, etc.
        lt.destroy if lt.last_observation_id.blank? && lt.can_be_auto_removed_from_check_list?
      end
    end
    add_new_listed_taxa(observation.taxon, new_place_ids) if observation
  end
  
  def self.get_observation_to_refresh(observation)
    if observation.is_a?(Observation)
      observation_id = observation.id
    else
      observation_id = observation.to_i
      observation = Observation.find_by_id(observation_id)
    end
    [observation, observation_id]
  end
  
  def self.get_taxon_ids_to_refresh(observation, options)
    taxon_id = observation.try(:taxon_id) || options[:taxon_id]
    taxon_ids = [taxon_id, options[:taxon_id_was]].compact
    taxa = Taxon.all(:conditions => ["id in (?)", taxon_ids])
    taxon_ids += taxa.map(&:ancestor_ids).flatten
    taxon_ids.uniq.compact
  end
  
  def self.get_current_place_ids_to_refresh(observation, options = {})
    observation_id = observation.try(:id) || options[:observation_id]
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
    place_ids.compact.uniq
  end
  
  def self.get_old_place_ids_to_refresh(observation, options = {})
    observation_id = observation.try(:id) || options[:observation_id]
    place_ids = Place.all(:include => :listed_taxa, :conditions => [
      "listed_taxa.first_observation_id = ? OR listed_taxa.last_observation_id = ?", 
      observation_id, observation_id])
    if (lat = options[:latitude_was]) && (lon = options[:longitude_was])
      place_ids += PlaceGeometry.all(:select => "place_geometries.id, place_id",
        :joins => "JOIN observations ON observations.id = #{observation_id}",
        :conditions => [
          "ST_Intersects(place_geometries.geom, ST_Point(?, ?))", lon, lat]
      ).map(&:place_id)
    end
    place_ids.compact.uniq
  end
  
  def self.add_new_listed_taxa(taxon, new_place_ids)
    CheckList.find_each(:joins => "JOIN places ON places.check_list_id = lists.id", 
        :conditions => ["place_id IN (?)", new_place_ids]) do |list|
      list.add_taxon(taxon, :force_update_observation_associates => true)
    end
  end
end
