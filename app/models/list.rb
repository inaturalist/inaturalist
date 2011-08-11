#
# A List is a list of taxa.  Naturalists often keep lists of taxa, whether
# they be lists of things they've seen, lists of things they'd like to see, or
# just lists of taxa that interest them for some reason.
#
class List < ActiveRecord::Base
  acts_as_activity_streamable
  belongs_to :user
  has_many :rules, :class_name => 'ListRule', :dependent => :destroy
  has_many :listed_taxa, :dependent => :destroy
  has_many :taxa, :through => :listed_taxa
  
  after_create :refresh
  
  validates_presence_of :title
  
  def to_s
    "<#{self.class} #{id}: #{title}>"
  end
  
  #
  # Adds a taxon to this list and returns the listed_taxon (valid or not). 
  # Note that subclasses like LifeList may override this.
  #
  def add_taxon(taxon, options = {})
    ListedTaxon.create(options.merge(:list => self, :taxon => taxon))
  end
  
  #
  # Update all the taxa in this list, or just a select few.  If taxa have been
  # more recently observed, their last_observation will be updated.  If taxa
  # were selected that were not in the list, they will be added if they've
  # been observed.
  #
  def refresh(options = {})
    if taxa = options[:taxa]
      collection = listed_taxa.all(:conditions => ["taxon_id IN (?)", taxa])
    else
      collection = listed_taxa.all
    end
    
    collection.each do |listed_taxon|
      # re-apply list rules to the listed taxa
      listed_taxon.save
      unless listed_taxon.valid?
        logger.debug "[DEBUG] #{listed_taxon} wasn't valid, so it's being " +
          "destroyed: #{listed_taxon.errors.full_messages.join(', ')}"
        listed_taxon.destroy
      end
    end
    true
  end
  
  # Determine whether this list can be edited or added to by a user. Default
  # permission is for the owner only. Override for subclasses.
  def editable_by?(user)
    user && self.user_id == user.id
  end
  
  def listed_taxa_editable_by?(user)
    editable_by?(user)
  end
  
  def owner_name
    self.user ? self.user.login : 'Unknown'
  end
  
  # Returns an associate that has observations
  def owner
    user
  end
  
  def last_observation_of(taxon)
    return nil unless taxon || user
    Observation.latest.by(user).first(:conditions => ["taxon_id = ?", taxon])
  end
  
  def refresh_key
    "refresh_list_#{id}"
  end
  
  def self.icon_preview_cache_key(list)
    {:controller => "lists", :action => "icon_preview", :list_id => list}
  end
  
  def self.refresh_for_user(user, options = {})
    options = {:add_new_taxa => true}.merge(options)
    
    # Find lists that needs refreshing (either LifeLists or normal lists with 
    # these taxa).  Another approach might be to look at all listed_taxa of
    # these taxa and all rules applying to ancestors of these taxa, but the
    # ancestry check will be performed by life lists during the validations
    # anyway, so it seems like duplication.
    target_lists = if options[:taxa]
      user.lists.all(
        :include => :listed_taxa,
        :conditions => [
          "listed_taxa.taxon_id in (?) OR type = ?", 
          options[:taxa], LifeList.to_s
        ]
      )
    else
      user.lists.all
    end
    
    target_lists.each do |list|
      logger.debug "[DEBUG] refreshing #{list}..."
      list.refresh(options)
    end
    true
  end
  
  def self.refresh(list, options = {})
    list = List.find_by_id(list) unless list.is_a?(List)
    if list.blank?
      Rails.logger.error "[ERROR #{Time.now}] Failed to refresh list #{list} because it doesn't exist."
    else
      list.refresh(options)
    end
  end
  
  # def self.refresh_with_observation(observation, options = {})
  #   observation = Observation.find_by_id(observation.to_i) unless observation.is_a?(Observation)
  #   return unless observation && observation.taxon
  #   user = observation.user
  #   ListedTaxon.update_all(
  #     ["last_observation_id = ?", observation], 
  #     ["list_id IN (?) AND taxon_id IN (?)", user.list_ids, [observation.taxon_id] + observation.taxon.ancestor_ids]
  #   )
  # end
end
