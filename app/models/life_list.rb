#
# A LifeList is a List of all the taxa a person has observed.
#
class LifeList < List
  belongs_to :place
  before_validation :set_defaults
  before_save :set_place_rule
  after_create :add_taxa_from_observations
  validate :place_has_boundary
  
  MAX_RELOAD_TRIES = 60

  def place_has_boundary
    if place_id && !PlaceGeometry.where(:place_id => place_id).exists?
      errors.add(:place_id, "must have a boundary")
    end
  end
  
  #
  # Adds a taxon to this life list by creating a new blank obs of the taxon
  # and relying on the callbacks in observation.  In theory, this should never
  # bonk on an invalid listed taxon...
  #
  def add_taxon(taxon, options = {})
    taxon_id = taxon.is_a?(Taxon) ? taxon.id : taxon
    if listed_taxon = listed_taxa.find_by_taxon_id(taxon_id)
      return listed_taxon
    end
    ListedTaxon.create(options.merge(:list => self, :taxon_id => taxon_id))
  end
  
  #
  # Update all the taxa in this list, or just a select few.  If taxa have no
  # longer been observed, they will be deleted.  If they have been more
  # recently observed, their last_observation will be updated.  If taxa were
  # selected that were not in the list, they will be added if they've been
  # observed.
  #
  def refresh(options = {})
    if taxa = options[:taxa]
      # Find existing listed_taxa of these taxa to update
      existing = ListedTaxon.where(list_id: self, taxon_id: taxa).
        includes([ {:list => :rules}, {:taxon => :taxon_names}, :last_observation ])
      collection = []
      
      # Add new listed taxa for taxa not already on this list
      if options[:add_new_taxa]
        taxa_ids = taxa.map do |taxon|
          if taxon.is_a?(Taxon)
            taxon.id
          elsif taxon.is_a?(Fixnum)
            taxon
          else
            nil
          end
        end.compact
        
        # Create new ListedTaxa for the taxa that aren't already in the list
        collection = (taxa_ids - existing.map{|e| e.taxon_id}).map do |taxon_id|
          listed_taxon = ListedTaxon.new(:list => self, :taxon_id => taxon_id)
          listed_taxon
        end
      end
      collection += existing
    else
      collection = self.listed_taxa.includes({list: :rules}, {taxon: :taxon_names}, :last_observation)
    end

    collection.each do |lt|
      lt.skip_update_cache_columns = options[:skip_update_cache_columns]
      lt.save
      if !lt.valid? || (lt.first_observation_id.blank? && lt.last_observation_id.blank? && !lt.manually_added?)
        lt.destroy
      end
    end
    true
  end
  
  def self.create_new_listed_taxa_for_refresh(taxon, listed_taxa, target_list_ids)
    new_list_ids = target_list_ids - listed_taxa.map{|lt| lt.taxon_id == taxon.id ? lt.list_id : nil}
    new_taxa = [taxon, taxon.species].compact
    new_list_ids.each do |list_id|
      new_taxa.each do |new_taxon|
        lt = ListedTaxon.new(:list_id => list_id, :taxon_id => new_taxon.id)
        unless lt.save
          Rails.logger.info "[INFO #{Time.now}] Failed to create #{lt}: #{lt.errors.full_messages.to_sentence}"
        end
      end
    end
  end
  
  def self.refresh_listed_taxon(lt)
    # checking this first so we don't save before we destroy
    # and incur unnecessary double cache-clearing
    lt.update_cache_columns
    if lt.first_observation.nil? && lt.last_observation.nil? && !lt.manually_added?
      lt.destroy
      return
    end
    unless lt.save
      lt.destroy
    end
  end
  
  def self.refresh_with_observation_lists(observation, options = {})
    user = observation.try(:user) || User.find_by_id(options[:user_id])
    user ? user.life_list_ids : []
  end
  
  # Add all the taxa the list's owner has observed.  Cache the job ID so we 
  # can display a loading notification on lists/show.
  def add_taxa_from_observations
    if job = LifeList.delay(priority: USER_PRIORITY,
      unique_hash: { "LifeList::add_taxa_from_observations": self.id }
    ).add_taxa_from_observations(self)
      Rails.cache.write(add_taxa_from_observations_key, job.id)
      true
    end
  end
  
  def add_taxa_from_observations_key
    "add_taxa_from_observations_job_#{id}"
  end
  
  def rule_taxon
    rules.detect{|r| r.operator == 'in_taxon?'}.try(:operand)
  end
  
  def self.add_taxa_from_observations(list, options = {})
    conditions = if options[:taxa]
      ["taxon_id IN (?)", options[:taxa]]
    else
      'taxon_id IS NOT NULL'
    end
    scope = list.owner.observations
    scope = scope.of(list.rule_taxon) if list.rule_taxon
    scope = scope.in_place(list.place) if list.place
    scope.select('DISTINCT ON(observations.taxon_id) observations.id, observations.taxon_id').
        where(conditions).each do |observation|
      list.add_taxon(observation.taxon_id, :last_observation_id => observation.id)
    end
  end
  
  def self.update_life_lists_for_taxon(taxon)
    ListRule.where([ "operator LIKE 'in_taxon%' AND operand_type = ? AND operand_id IN (?)",
      Taxon.to_s, [ taxon.id, taxon.ancestor_ids ].flatten.compact ]).
      includes(:list).find_in_batches do |batch|
      batch.each do |list_rule|
        next unless list_rule.list.is_a?(LifeList)
        LifeList.delay(priority: INTEGRITY_PRIORITY,
          unique_hash: { "LifeList::add_taxa_from_observations": list_rule.list_id }).
          add_taxa_from_observations(list_rule.list, :taxa => [taxon.id])
      end
    end
  end
  
  def reload_from_observations
    if job = LifeList.delay(priority: USER_PRIORITY,
      unique_hash: { "LifeList::reload_from_observations": self.id }
    ).reload_from_observations(self)
      Rails.cache.write(reload_from_observations_cache_key, job.id)
      job
    end
  end
  
  def reload_from_observations_cache_key
    "reload_list_from_obs_#{id}"
  end

  def set_place_rule
    existing = rules.detect{|r| r.operator == "observed_in_place?"}
    if place.blank? && existing
      existing.destroy
    elsif place && !existing
      self.rules.build(:operator => "observed_in_place?")
    end
    true
  end
  
  def self.reload_from_observations(list)
    list = List.find_by_id(list) unless list.is_a?(List)
    return unless list
    if list.is_a?(ProjectList)
      ProjectList.repair_observed(list)
      ProjectList.add_taxa_from_observations(list)
    else
      repair_observed(list)
      add_taxa_from_observations(list)
    end
  end
  
  def self.repair_observed(list)
    ListedTaxon.where(
      [ "list_id = ? AND observations.id IS NOT NULL AND observations.taxon_id != listed_taxa.taxon_id", list ]).
      joins({ :last_observation => :taxon }, :taxon).find_in_batches do |batch|
      batch.each do |lt|
        lt.destroy unless lt.valid? && lt.last_observation && lt.last_observation.taxon.descendant_of?(lt.taxon)
      end
    end
  end

  def cache_columns_options(lt)
    lt = ListedTaxon.find_by_id(lt) unless lt.is_a?(ListedTaxon)
    return nil unless lt
    return super if lt.list.place.blank?
    options = { search_params: {
      where: {
        "taxon.ancestor_ids": lt.taxon_id,
        place_ids: lt.list.place } } }
    if user_id
      options[:search_params][:where]["user.id"] = user_id
    end
    options
  end

  def default_title
    default = "%s's Life List" % owner_name
    default += " of #{rule_taxon.default_name.name}" if rule_taxon
    default
  end

  def default_description
    nil
  end

  def description
    if user && id == user.life_list_id
      nil
    else
      read_attribute(:description)
    end
  end

  private
  def set_defaults
    if title.blank?
      self.title = default_title
    end
    if description.blank? && rule_taxon.blank?
      self.description = default_description
    end
    true
  end
end
