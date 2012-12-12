#
# A LifeList is a List of all the taxa a person has observed.
#
class LifeList < List
  before_validation :set_defaults
  after_create :add_taxa_from_observations
  
  MAX_RELOAD_TRIES = 60
  
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
      existing = ListedTaxon.all(
        :include => [{:list => :rules}, {:taxon => :taxon_names}, :last_observation],
        :conditions => ["list_id = ? AND taxon_id IN (?)", self, taxa])
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
      collection = self.listed_taxa.all(:include => [{:list => :rules}, {:taxon => :taxon_names}, :last_observation])
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
    unless lt.save
      lt.destroy
      return
    end
    if lt.first_observation_id.blank? && lt.last_observation_id.blank? && !lt.manually_added?
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
    job = LifeList.delay.add_taxa_from_observations(self)
    Rails.cache.write(add_taxa_from_observations_key, job.id)
    true
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
    # Note: this should use find_each, but due to a bug in rails < 3,
    # conditions in find_each get applied to scopes utilized by anything
    # further up the call stack, causing bugs.
    scope = list.owner.observations.scoped
    scope = scope.of(list.rule_taxon) if list.rule_taxon
    scope.all(
        :select => 'DISTINCT ON(observations.taxon_id) observations.id, observations.taxon_id', 
        :conditions => conditions).each do |observation|
      list.add_taxon(observation.taxon_id, :last_observation_id => observation.id)
    end
  end
  
  def self.update_life_lists_for_taxon(taxon)
    ListRule.do_in_batches(:include => :list, :conditions => [
      "operator LIKE 'in_taxon%' AND operand_type = ? AND operand_id IN (?)", 
      Taxon.to_s, [taxon.id, taxon.ancestor_ids].flatten.compact
    ]) do |list_rule|
      next unless list_rule.list.is_a?(LifeList)
      next if Delayed::Job.where("handler LIKE '%add_taxa_from_observations%id: ''#{list_rule.list_id}''%'").exists?
      LifeList.delay(:priority => INTEGRITY_PRIORITY).add_taxa_from_observations(list_rule.list, :taxa => [taxon.id])
    end
  end
  
  def reload_from_observations
    job = LifeList.delay.reload_from_observations(self)
    Rails.cache.write(reload_from_observations_cache_key, job.id)
    job
  end
  
  def reload_from_observations_cache_key
    "reload_list_from_obs_#{id}"
  end
  
  def self.reload_from_observations(list)
    repair_observed(list)
    add_taxa_from_observations(list)
  end
  
  def self.repair_observed(list)
    ListedTaxon.do_in_batches(
        :include => [{:last_observation => :taxon}, :taxon], 
        :conditions => [
          "list_id = ? AND observations.id IS NOT NULL AND observations.taxon_id != listed_taxa.taxon_id",
          list.id]) do |lt|
      lt.destroy unless lt.last_observation.taxon.descendant_of?(lt.taxon)
    end
  end
  
  private
  def set_defaults
    if title.blank?
      self.title = "%s's Life List" % owner_name
      self.title += " of #{rule_taxon.default_name.name}" if rule_taxon
    end
    if description.blank? && rule_taxon.blank?
      self.description = "Every species seen by #{owner_name}"
    end
    true
  end
end
