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
  
  def to_s
    "<List #{self.id}: #{self.title}>"
  end
  
  #
  # Adds a taxon to this list and returns the listed_taxon (valid or not). 
  # Note that subclasses like LifeList may override this.
  #
  def add_taxon(taxon)
    ListedTaxon.create(:list => self, :taxon => taxon)
  end
  
  #
  # Update all the taxa in this list, or just a select few.  If taxa have been
  # more recently observed, their last_observation will be updated.  If taxa
  # were selected that were not in the list, they will be added if they've
  # been observed.
  #
  def refresh(params = {})
    if taxa = params[:taxa]
      collection = ListedTaxon.find(:all,
        :conditions => ["list_id = ? AND taxon_id IN (?)", self, taxa])
    else
      collection = self.listed_taxa
    end
    
    collection.each do |listed_taxon|      
      # update it
      listed_taxon = listed_taxon.update_last_observation
      
      # re-apply list rules to the listed taxa
      listed_taxon.save
      unless listed_taxon.valid?
        logger.debug "[DEBUG] #{listed_taxon} wasn't valid, so it's being " +
          "destroyed: #{listed_taxon.errors.full_messages.join(', ')}"
        listed_taxon.destroy
      end
    end
  end
  
  # Determine whether this list can be edited or added to by a user. Default
  # permission is for the owner only. Override for subclasses.
  def editable_by?(user)
    user && self.user_id == user.id
  end
  
  def owner_name
    self.user ? self.user.login : 'Unknown'
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
    
    logger.debug "[DEBUG] Updating lists.  options: #{options}"
    target_lists.each do |list|
      list.refresh(options)
    end
    true
  end
end
