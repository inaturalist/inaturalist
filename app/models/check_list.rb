# CheckLists are lists of Taxa that occur in a Place.
class CheckList < List
  belongs_to :taxon
  belongs_to :source
  
  accepts_nested_attributes_for :source
  
  before_validation :set_title
  before_create :set_last_synced_at
  after_create :refresh
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
    return unless taxon || place
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
  
  def refresh_cache_key
    "refresh_list_#{id}"
  end

  def reload_from_observations_cache_key
    "rfo_list_#{id}"
  end

  def add_taxon(taxon, options = {})
    options[:place_id] = place_id
    super(taxon, options)
  end
  
  def add_observed_taxa(options = {})
    # TODO remove this when we move to GEOGRAPHIES and our dateline woes have (hopefully) ended
    return if place.straddles_date_line?

    observed_taxon_ids = []
    search_params = {
      place_id: place_id,
      quality_grade: Observation::RESEARCH_GRADE,
      taxon_geoprivacy: "open",
      geoprivacy: "open"
    }
    if taxon
      search_params[:taxon_id] = taxon.id
    end
    Observation.search_in_batches( search_params ) do |batch|
      observed_taxon_ids += batch.map(&:taxon_id)
      observed_taxon_ids.uniq!
    end
    # Don't index the taxon with each new ListedTaxon. Instead do it in batches
    # and give ES a break
    options_without_indexing = options.merge(
      skip_index_taxon: true,
      place: place
    )
    observed_taxon_ids.in_groups_of( 500 ) do |taxon_ids|
      taxa = Taxon.where( id: taxon_ids )
      taxa.each do |taxon|
        add_taxon( taxon, options_without_indexing )
      end
      Taxon.elastic_index!( ids: taxon_ids )
    end
  end
  
  # For CheckLists, returns first_observation_id which represents the first one added to the site (e.g. not first date observed)
  def cache_columns_options(lt)
    lt = ListedTaxon.find_by_id(lt) unless lt.is_a?(ListedTaxon)
    return nil unless lt && lt.taxon_id
    filters = [ { term: { "taxon.ancestor_ids.keyword": lt.taxon_id } } ]
    filters << { term: { "place_ids.keyword": lt.place.id } } if lt.place
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
      batch.map( &:taxon_id ).uniq.each do |taxon_id|
        Taxon.delay(priority: INTEGRITY_PRIORITY, run_at: 1.hour.from_now,
          unique_hash: { "Taxon::elastic_index": taxon_id }).
          elastic_index!(ids: [taxon_id])
      end
    end
    true
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
        listed_taxon.primary_listed_taxon.update_on_related_listed_taxa
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
    unless listed_taxa.blank? || options[:new]
      Rails.logger.info "[INFO #{Time.now}] refresh_with_observation #{observation_id}, updating #{listed_taxa.size} existing listed taxa"
      listed_taxa.each do |lt|
        CheckList.delay(priority: INTEGRITY_PRIORITY, queue: "slow", run_at: 2.hours.from_now,
          unique_hash: { "CheckList::refresh_listed_taxon": lt.id }
        ).refresh_listed_taxon( lt.id )
      end
    end
    if observation && observation.research_grade? && observation.taxon.species_or_lower?
      Rails.logger.info "[INFO #{Time.now}] refresh_with_observation #{observation_id}, adding new listed taxa"
      add_new_listed_taxa( observation.taxon, new_place_ids, current_place_ids, taxon_ids )
    end
    Rails.logger.info "[INFO #{Time.now}] refresh_with_observation #{observation_id}, finished"
  end

  def self.refresh_listed_taxon(lt, options = {})
    lt = ListedTaxon.find_by_id(lt) unless lt.is_a?(ListedTaxon)
    return unless lt
    # save sets all observation associates, months stats, etc.
    lt.force_update_cache_columns = true
    # these associations will get loaded during the model save callbacks. Forcing them to be
    # loaded here, outside the save transaction, so the queries will be run on replica DBs
    ListedTaxon.preload_associations( lt, [{ list: :rules }, :taxon, :place])
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
  
  def self.add_new_listed_taxa(taxon, new_place_ids, current_place_ids, taxon_ids)
    check_lists = CheckList.where(place_id: new_place_ids).
      joins("JOIN places ON places.check_list_id = lists.id")
    atlases = Atlas.where( "is_active = ? AND taxon_id IN ( ? )", true, taxon_ids )
    complete_sets = CompleteSet.where(
      "is_active =  ? AND taxon_id IN ( ? ) AND place_id IN ( ? )",
      true, taxon_ids, current_place_ids
    )
    check_lists.each do |list|
      if [Place::COUNTRY_LEVEL ,Place::STATE_LEVEL ,Place::COUNTY_LEVEL].include?( list.place.admin_level )
        if atlases.exists?
          atlas_that_excludes_check_list_place = atlases.detect do |atlas|
            # If an atlas's presence places do not overlap with the list's place
            # and ancestor places, the atlas excludes the list's place
            ( atlas.presence_places.pluck(:id) & list.place.self_and_ancestor_ids ).size == 0
          end
          if atlas_that_excludes_check_list_place
            next
          end
        end
        if complete_sets.exists?
          complete_set_that_excludes_taxon = complete_sets.detect do |complete_set|
            # A complete set implies that there are listed taxa for all species
            # in the taxon for that place, so if there is no listed taxon for
            # this taxon in the complete set place, it should be excluded
            !ListedTaxon.where( place_id: complete_set.place_id, taxon_id: taxon.id ).exists?
          end
          if complete_set_that_excludes_taxon
            next
          end
        end
      end
      list.add_taxon( taxon, force_update_cache_columns: true )
      if taxon.rank_level < Taxon::SPECIES_LEVEL
        list.add_taxon( taxon.species, force_update_cache_columns: true )
      end
    end
  end

  def self.refresh(options = {})
    start = Time.now
    log_key = "#{name}.refresh #{start}"
    Rails.logger.info "[INFO #{Time.now}] Starting #{log_key}, options: #{options.inspect}"
    lists = options.delete(:lists)
    lists ||= [options] if options.is_a?(self)
    lists ||= [find_by_id(options)] unless options.is_a?(Hash)
    if options[:taxa]
      lists ||= self.joins(:listed_taxa).
        where("lists.type = ? AND listed_taxa.taxon_id IN (?)", self.name, options[:taxa])
    end

    if lists.blank?
      Rails.logger.error "[ERROR #{Time.now}] Failed to refresh lists for #{options.inspect} " + 
        "because there are no matching lists."
    else
      lists.each do |list|
        Rails.logger.info "[INFO #{Time.now}] #{log_key}, refreshing #{list}"
        list.delay(priority: INTEGRITY_PRIORITY, queue: list.is_a?(CheckList) ? "slow" : "default",
          unique_hash: { "#{ list.class.name }::refresh": { list_id: list.id, options: options } }
        ).refresh(options)
      end
    end
    Rails.logger.info "[INFO #{Time.now}] #{log_key}, finished in #{Time.now - start}s"
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
