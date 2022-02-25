class CompleteSet < ApplicationRecord
  has_subscribers
  belongs_to :taxon
  belongs_to :user
  belongs_to :place
  belongs_to :source
  has_many :comments, as: :parent, dependent: :destroy
  validates_uniqueness_of :taxon_id, scope: :place_id, :message => "already has complete set for this place"
  validates_presence_of :taxon
  validates_presence_of :place
  
  def get_taxa_for_place_taxon
    place_descendant_ids = place.descendants.
      where( "admin_level IN (?)", [Place::COUNTRY_LEVEL, Place::STATE_LEVEL, Place::COUNTY_LEVEL] ).pluck( :id )
    place_with_descendant_ids = [place.id, place_descendant_ids].compact.flatten
    taxon_descendant_ids = taxon.subtree.
      where( "taxa.is_active = true AND taxa.rank != 'hybrid' AND taxa.rank_level <= ?", Taxon::RANK_LEVELS["species"] ).
      joins( "LEFT OUTER JOIN conservation_statuses ON conservation_statuses.taxon_id = taxa.id" ).
      where( "conservation_statuses.id IS NULL OR conservation_statuses.iucn < ?", Taxon::IUCN_EXTINCT_IN_THE_WILD).
      pluck( :id )
    #these are all listed sp+spp in places/desc places
    taxon_ids = ListedTaxon.joins( { list: :check_list_place } ).where( "lists.type = 'CheckList'" ).
      where( "listed_taxa.taxon_id IN ( ? )", taxon_descendant_ids ).
      where( "listed_taxa.place_id IN ( ? )", place_with_descendant_ids ).
      pluck(:taxon_id).uniq
    #roll spp up to sp
    rolled_taxon_ids = Taxon.where( id: taxon_ids ).
      map{ |t| ( t.rank_level && t.rank_level < Taxon::RANK_LEVELS["species"] ) ?  t.ancestor_ids.last : t.id }
    Taxon.where( id: rolled_taxon_ids )
  end

  def relevant_listed_taxon_alterations
    place_descendant_ids = place.descendants.
      where( "admin_level IN (?)", [Place::COUNTRY_LEVEL, Place::STATE_LEVEL, Place::COUNTY_LEVEL] ).pluck( :id )
    place_with_descendant_ids = [place.id, place_descendant_ids].compact.flatten
    taxon_descendant_ids = taxon.subtree.
      where( "taxa.is_active = true AND taxa.rank_level <= ?", Taxon::RANK_LEVELS["species"] ).
      pluck( :id )
    scope = ListedTaxonAlteration.joins( :place ).where( "place_id IN ( ? )", place_with_descendant_ids ).
      where( "taxon_id IN ( ? )", taxon_descendant_ids )
    scope
  end
end