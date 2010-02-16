#
# A LifeList is a List of all the taxa a person has observed.
#
class LifeList < List
  before_create :set_defaults
  after_create :add_taxa_from_observations
  
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
  def refresh(params = {})
    if taxa = params[:taxa]
      # Find existing listed_taxa of these taxa to update
      existing = ListedTaxon.all(:conditions => [
        "list_id = ? AND taxon_id IN (?)", self, taxa])
      
      # Add new listed taxa for taxa not already on this list
      if params[:add_new_taxa]
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
        collection = (taxa_ids - existing.map(&:taxon_id)).map do |taxon_id|
          listed_taxon = ListedTaxon.new(:list => self, :taxon_id => taxon_id)
          listed_taxon.skip_update = true
          listed_taxon
        end
        collection += existing
      end
    else
      collection = self.listed_taxa
    end

    collection.each do |listed_taxon|
      # re-apply list rules to the listed taxa
      unless listed_taxon.save
        logger.debug "[DEBUG] #{listed_taxon} wasn't valid in #{self}, so " + 
          "it's being destroyed: " + 
          listed_taxon.errors.full_messages.join(', ')
        listed_taxon.destroy
      end
    end
  end
  
  # Add all the taxa the list's owner has observed.  Cache the job ID so we 
  # can display a loading notification on lists/show.
  def add_taxa_from_observations
    job = LifeList.send_later(:add_taxa_from_observations, self)
    Rails.cache.write("add_taxa_from_observations_job_#{id}", job.id)
    true
  end
  
  def self.add_taxa_from_observations(list, options = {})
    conditions = if options[:taxa]
      ["taxon_id IN (?)", options[:taxa]]
    else
      'taxon_id > 0'
    end
    list.user.observations.find_each(:select => 'id, taxon_id', 
        :group => 'taxon_id', 
        :conditions => conditions) do |observation|
      list.add_taxon(observation.taxon_id, :last_observation_id => observation.id)
    end
  end
  
  def self.update_life_lists_for_taxon(taxon)
    ListRule.find_each(:include => :list, :conditions => [
      "operator LIKE 'in_taxon%' AND operand_type = ? AND operand_id IN (?)", 
      Taxon.to_s, taxon.self_and_ancestors.map(&:id)
    ]) do |list_rule|
      next unless list_rule.list.is_a?(LifeList)
      LifeList.send_later(:add_taxa_from_observations, list_rule.list, 
        :taxa => [taxon.id])
    end
  end
  
  private
  def set_defaults
    self.title ||= "%s's Life List" % self.user.login
    self.description ||= "Every species %s has ever seen." % self.user.login
    true
  end
end
