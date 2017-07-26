# CheckLists are lists of Taxa that occur in a Place.
class CheckList < List
  belongs_to :place
  belongs_to :taxon
  belongs_to :source
  
  accepts_nested_attributes_for :source
  
  before_validation :set_title
  before_create :set_last_synced_at
  before_save :update_taxon_list_rule
  # after_save :mark_non_comprehensive_listed_taxa_as_absent
  
  validates_presence_of :place_id
  validates_uniqueness_of :taxon_id, :scope => :place_id, :allow_nil => true,
    :message => "already has a check list for this place."
  
  # TODO: the following should work through list rules
  # validates_uniqueness_of :taxon_id, :scope => :place_id
  
  MAX_RELOAD_TRIES = 60
  
  def to_s
    "<#{self.class} #{id}: #{title} taxon_id: #{taxon_id} place_id: #{place_id}>"
  end
  
  def editable_by?(user)
    user && (self.user == user || user.is_curator?)
  end
  
  def listed_taxa_editable_by?(user)
    return false if user.blank?
    return true if self.user == user || user.is_curator?
    return false if comprehensive?
    true
  end
  
  def owner_name
    self.place.name
  end
  
  # Is this the default check list of its place?
  def is_default?
    self.place.check_list_id == self.id
  end
  
  def update_taxon_list_rule
    return true unless taxon_id_changed?
    self.rules.each(&:destroy)
    unless taxon.blank?
      self.rules.build(:operand => self.taxon, :operator => 'in_taxon?')
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
    scope = ListedTaxon.includes(:taxon).where(place_id: place_id)
    unless options.delete(:force)
      time_since_last_sync = options.delete(:time_since_last_sync) || 1.hour.ago
      scope = scope.where("listed_taxa.created_at > ?", time_since_last_sync)
    end
    return if self.place.parent.blank?
    return unless parent_check_list = self.place.parent.check_list
    scope.find_each do |lt|
      Rails.logger.info "[INFO #{Time.now}] syncing check list #{id} with parent #{parent_check_list.id}, working on #{lt}"
      if parent_check_list.listed_taxa.exists?(:taxon_id => lt.taxon_id)
        Rails.logger.info "[INFO #{Time.now}] syncing check list #{id} with parent #{parent_check_list.id}, taxon already on parent list, skipping..."
        next
      end
      Rails.logger.info "[INFO #{Time.now}] syncing check list #{id} with parent #{parent_check_list.id}, adding taxon #{lt.taxon_id} to parent list"
      parent_check_list.add_taxon(lt.taxon, options)
      Rails.logger.info "[INFO #{Time.now}] syncing check list #{id} with parent #{parent_check_list.id}, done with #{lt}"
    end
    parent_check_list.update_attribute(:last_synced_at, Time.now)
    Rails.logger.info "[INFO #{Time.now}] Finished syncing check list #{id} with parent #{parent_check_list.id}"
  end
  
  def add_taxon(taxon, options = {})
    options[:place_id] = place_id
    super(taxon, options)
  end
  
  # This is a loaded gun.  Please fire with discretion.
  def add_intersecting_taxa(options = {})
    return nil unless PlaceGeometry.exists?(["place_id = ?", place_id])
    if place.straddles_date_line?
      raise "Can't add intersecting taxa for places that span the dateline. Maybe it would work if we switched from geometries to geographies."
    end
    ancestor = options[:ancestor].is_a?(Taxon) ? options[:ancestor] : Taxon.find_by_id(options[:ancestor])
    if options[:ancestor] && ancestor.blank?
      return nil
    end
    scope = Taxon.intersecting_place(place)
    scope = scope.descendants_of(ancestor) if ancestor
    scope.find_each(:select => "taxa.*, taxon_ranges.id AS taxon_range_id") do |taxon|
      add_taxon(taxon.id, :taxon_range_id => taxon.taxon_range_id, 
        :skip_update_cache_columns => options[:skip_update_cache_columns],
        :skip_sync_with_parent => options[:skip_sync_with_parent])
    end
  end
  
  def add_observed_taxa(options = {})
    # TODO remove this when we move to GEOGRAPHIES and our dateline woes have (hopefully) ended
    return if place.straddles_date_line?

    Observation.where("observations.quality_grade = ? AND ST_Intersects(place_geometries.geom, observations.private_geom)",
                  Observation::RESEARCH_GRADE).
                select("DISTINCT ON (observations.taxon_id) observations.id, observations.taxon_id, observations.user_id").
                order("observations.taxon_id").
                includes(:taxon, :user).
                joins("JOIN place_geometries ON place_geometries.place_id = #{place_id}").each do |observation|
      add_taxon(observation.taxon, options)
    end
  end
  
  # For CheckLists, returns first_observation_id which represents the first one added to the site (e.g. not first date observed)
  def cache_columns_options(lt)
    lt = ListedTaxon.find_by_id(lt) unless lt.is_a?(ListedTaxon)
    return nil unless lt && lt.taxon_id
    filters = [ { term: { "taxon.ancestor_ids": lt.taxon_id } } ]
    filters << { term: { place_ids: lt.place.id } } if lt.place
    { filters: filters,
      earliest_sort_field: "id",
      range_filters: [ { term: { quality_grade: "research" } } ] }
  end
  
  # not sure why I originally added this.  Doesn't make sense for taxa on non-comprehensive list 
  # to be "absent," since they're obviously present if they're on the comprehensive list.
  def mark_non_comprehensive_listed_taxa_as_absent
    return true unless comprehensive_changed?
    return true unless comprehensive?
    ancestry = [taxon.ancestry, taxon.id].compact.join('/')
    conditions = [
      "place_id = ? AND list_id != ? AND (taxa.ancestry = ? OR taxa.ancestry LIKE ?)",
      place_id, id, ancestry, "#{ancestry}/%"
    ]
    that = self
    ListedTaxon.joins(:taxon).where(conditions).find_each do |lt|
      next if that.listed_taxa.exists?(:taxon_id => lt.taxon_id)
      ListedTaxon.where(id: lt.id).update_all(occurrence_status_level: ListedTaxon::ABSENT)
    end
    true
  end
  
  def refresh(options = {})
    finder = ListedTaxon.all
    if taxa = options[:taxa]
      finder = finder.where(list_id: self.id, taxon_id: taxa)
    else
      finder = finder.where(list_id: self.id)
    end
    
    finder.includes({
      taxon: [:taxon_names],
      list: [:rules],
      last_observation: [:taxon] }).find_in_batches do |batch|
      batch.each do |listed_taxon|
        listed_taxon.skip_update_cache_columns = options[:skip_update_cache_columns]
        listed_taxon.skip_index_taxon = true
        # re-apply list rules to the listed taxa
        listed_taxon.force_update_cache_columns = true
        listed_taxon.check_primary_listing
        listed_taxon.save
        # make sure we don't force update yet again when just validating
        listed_taxon.force_update_cache_columns = false
        if !listed_taxon.valid?
          Rails.logger.debug "[DEBUG] #{listed_taxon} wasn't valid, so it's being " +
            "destroyed: #{listed_taxon.errors.full_messages.join(', ')}"
          listed_taxon.destroy
        elsif listed_taxon.auto_removable_from_check_list?
          listed_taxon.destroy
        end
      end
      Taxon.elastic_index!(scope: Taxon.where(id: batch.map(&:taxon_id).uniq))
    end
    true
  end
  
  def reload_and_refresh_now
    if job = CheckList.delay(priority: USER_PRIORITY,
      unique_hash: { "CheckList::reload_and_refresh_now": self.id }
    ).reload_and_refresh_now(self)
      Rails.cache.write(reload_and_refresh_now_cache_key, job.id)
      job
    end
  end
  
  def reload_and_refresh_now_cache_key
    "reload_and_refresh_now_#{id}"
  end
  
  def refresh_now_without_reload
    if job = CheckList.delay(priority: USER_PRIORITY,
      unique_hash: { "CheckList::refresh_now_without_reload": self.id }
    ).refresh_now_without_reload(self)
      Rails.cache.write(refresh_now_without_reload_cache_key, job.id)
      job
    end
  end
  
  def refresh_now_without_reload_cache_key
    "refresh_now_without_reload_#{id}"
  end
  
  def refresh_now(options = {})
    scope = if taxa = options[:taxa]
      ListedTaxon.where(list_id: self.id, taxon_id: taxa)
    else
      ListedTaxon.where(list_id: self.id)
    end
    
    scope.find_each do |listed_taxon|
      if listed_taxon.primary_listing
        ListedTaxon.update_cache_columns_for(listed_taxon)
      else
        listed_taxon.primary_listed_taxon.update_attributes_on_related_listed_taxa
      end
      if !listed_taxon.valid?
        Rails.logger.debug "[DEBUG] #{listed_taxon} wasn't valid, so it's being " +
          "destroyed: #{listed_taxon.errors.full_messages.join(', ')}"
        listed_taxon.destroy
      elsif listed_taxon.auto_removable_from_check_list?
        listed_taxon.destroy
      end
    end
    true
  end
  
  def self.sync_check_lists_with_parents(options = {})
    time_since_last_sync = options[:time_since_last_sync] || 1.hour.ago
    start_time = Time.now
    Rails.logger.info "[INFO] Starting CheckList.sync_check_lists_with_parents " + 
      "at #{start_time}..."

    ListedTaxon.where("listed_taxa.place_id IS NOT NULL AND listed_taxa.created_at > ?",
      time_since_last_sync).includes(
      [:taxon, :list, {:place => {:parent => :check_list}}]).each do |listed_taxon|
      next unless listed_taxon.place.parent_id
      parent_check_list = listed_taxon.place.parent.check_list
      next if listed_taxon.has_atlas_or_complete_set?
      next if parent_check_list.listed_taxa.exists?(:taxon_id => listed_taxon.taxon_id)
      parent_check_list.add_taxon(listed_taxon.taxon)
    end
    parent_check_list.update_attribute(:last_synced_at, Time.now)

    Rails.logger.info "[INFO] Finished CheckList.sync_check_lists_with_parents " + 
      "at #{Time.now} (#{Time.now - start_time}s)"
  end
  
  def self.refresh_with_observation(observation, options = {})
    observation, observation_id = CheckList.get_observation_to_refresh(observation)
    options[:observation_id] ||= observation_id
    taxon_ids = CheckList.get_taxon_ids_to_refresh(observation, options)
    return if taxon_ids.blank?
    Rails.logger.info "[INFO #{Time.now}] refresh_with_observation #{observation_id}, taxon_ids: #{taxon_ids.inspect}"
    
    current_place_ids = CheckList.get_current_place_ids_to_refresh(observation, options)
    Rails.logger.info "[INFO #{Time.now}] refresh_with_observation #{observation_id}, current_place_ids: #{current_place_ids.inspect}"
    
    current_listed_taxa = ListedTaxon.where(place_id: current_place_ids, taxon_id: taxon_ids)
    current_listed_taxa_of_this_taxon = current_listed_taxa.select{|lt| lt.taxon_id == observation.taxon_id}
    new_place_ids = current_place_ids - current_listed_taxa_of_this_taxon.map{|lt| lt.place_id}
    Rails.logger.info "[INFO #{Time.now}] refresh_with_observation #{observation_id}, new_place_ids: #{new_place_ids.inspect}"
    
    old_place_ids = CheckList.get_old_place_ids_to_refresh(observation, options)
    Rails.logger.info "[INFO #{Time.now}] refresh_with_observation #{observation_id}, old_place_ids: #{old_place_ids.inspect}"
    
    old_listed_taxa = ListedTaxon.where(place_id: (old_place_ids - current_place_ids), taxon_id: taxon_ids)
    listed_taxa = (current_listed_taxa + old_listed_taxa).compact.uniq
    unless listed_taxa.blank?
      Rails.logger.info "[INFO #{Time.now}] refresh_with_observation #{observation_id}, updating #{listed_taxa.size} existing listed taxa"
      listed_taxa.each do |lt|
        CheckList.delay(priority: INTEGRITY_PRIORITY, queue: "slow", run_at: 30.minutes.from_now,
          unique_hash: { "CheckList::refresh_listed_taxon": lt.id }
        ).refresh_listed_taxon( lt.id )
      end
    end
    if observation && observation.research_grade? && observation.taxon.species_or_lower?
      Rails.logger.info "[INFO #{Time.now}] refresh_with_observation #{observation_id}, adding new listed taxa"
      if Atlas.where( "is_active = ? AND taxon_id IN ( ? )", true, taxon_ids ).count > 0 ||
        CompleteSet.where( "is_active =  ? AND taxon_id IN ( ? ) AND place_id IN ( ? )", true, taxon_ids, current_place_ids ).any?
        #if under atlas or complete set,
        #don't create listings for places of admin_level 0,1,2
        new_place_ids = Place.where( id: new_place_ids ).
          where( "admin_level IS NULL OR admin_level NOT IN (?)", [Place::COUNTRY_LEVEL ,Place::STATE_LEVEL ,Place::COUNTY_LEVEL] ).pluck( :id )
      end
      add_new_listed_taxa( observation.taxon, new_place_ids )
    end
    Rails.logger.info "[INFO #{Time.now}] refresh_with_observation #{observation_id}, finished"
  end

  def self.refresh_listed_taxon(lt, options = {})
    lt = ListedTaxon.find_by_id(lt) unless lt.is_a?(ListedTaxon)
    return unless lt
    # save sets all observation associates, months stats, etc.
    lt.force_update_cache_columns = true
    unless lt.save
      Rails.logger.error "[ERROR #{Time.now}] Couldn't save #{lt}: #{lt.errors.full_messages.to_sentence}"
    end
    if lt.auto_removable_from_check_list? && !options[:new]
      lt.destroy
    end
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
    taxa = Taxon.where(id: taxon_ids)
    taxon_ids += taxa.map{|t| t.ancestor_ids}.flatten
    taxon_ids.uniq.compact
  end
  
  def self.get_current_place_ids_to_refresh(observation, options = {})
    return [] unless observation
    observation.public_places.map{|p| p.id}
  end
  
  def self.get_old_place_ids_to_refresh(observation, options = {})
    observation_id = observation.try(:id) || options[:observation_id]
    place_ids = Place.where("listed_taxa.first_observation_id = ? OR listed_taxa.last_observation_id = ?",
      observation_id, observation_id).joins(:listed_taxa).map{ |p| p.id }
    if (lat = options[:latitude_was]) && (lon = options[:longitude_was])
      place_ids += PlaceGeometry.joins("JOIN observations ON observations.id = #{observation_id}").
        where("ST_Intersects(place_geometries.geom, ST_Point(?, ?))", lon, lat).
        select("place_geometries.id, place_id").map{ |pg| pg.place_id }
    end
    place_ids.compact.uniq
  end
  
  def self.add_new_listed_taxa(taxon, new_place_ids)
    CheckList.where(place_id: new_place_ids).
      joins("JOIN places ON places.check_list_id = lists.id").each do |list|
      list.add_taxon(taxon, :force_update_cache_columns => true)
      list.add_taxon(taxon.species, :force_update_cache_columns => true) if taxon.rank_level < Taxon::SPECIES_LEVEL
    end
  end

  def find_listed_taxa_and_ancestry_as_hashes
    listed_taxa_on_this_list_with_ancestry_string = ActiveRecord::Base.connection.execute("select listed_taxa.id, taxon_id, taxa.ancestry from listed_taxa, taxa where listed_taxa.taxon_id = taxa.id and list_id = #{id};")
    listed_taxa_on_this_list_with_ancestry_string.map{|row| row['ancestry'] = row['ancestry'].to_s.split("/"); row }
  end

  def find_listed_taxa_and_ancestry_on_other_lists_as_hashes(list_ids)
    listed_taxa_not_on_this_list_but_on_this_place_with_ancestry_string = ActiveRecord::Base.connection.execute("select listed_taxa.id, taxon_id, list_id, taxa.ancestry from listed_taxa, taxa where listed_taxa.taxon_id = taxa.id and list_id IN (#{list_ids.join(', ')})")
    listed_taxa_on_other_lists_with_ancestry = listed_taxa_not_on_this_list_but_on_this_place_with_ancestry_string.map{|row| row['ancestry'] = (row['ancestry'].present? ? row['ancestry'].split("/") : []); row }
  end
end
