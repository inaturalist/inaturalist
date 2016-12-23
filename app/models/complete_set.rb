class CompleteSet < ActiveRecord::Base
  has_subscribers
  belongs_to :taxon
  belongs_to :user
  belongs_to :place
  belongs_to :source
  has_many :comments, as: :parent, dependent: :destroy

  def get_taxa_for_place_taxon
    place_descendant_ids = place.descendants.where('admin_level IN (?)',[0,1,2]).pluck(:id)
    place_with_descendant_ids = [place.id, place_descendant_ids].compact.flatten
    taxon_descendant_ids = taxon.taxon_ancestors_as_ancestor.joins(:taxon).
      where("taxa.is_active = true AND taxa.rank_level <= ?",Taxon::RANK_LEVELS["species"]).
      pluck(:taxon_id)
    taxon_ids = ListedTaxon.joins( { list: :check_list_place } ).where( "lists.type = 'CheckList'").
      where( "listed_taxa.taxon_id IN (?)", taxon_descendant_ids).
      where("listed_taxa.place_id IN (?)", place_with_descendant_ids).
      pluck(:taxon_id).uniq #these are all listed sp+spp in places/desc places
    rolled_taxon_ids = Taxon.where(id: taxon_ids). #roll spp up to sp
      map{|t| (t.rank_level && t.rank_level < Taxon::RANK_LEVELS["species"]) ?  t.ancestor_ids.last : t.id}
    Taxon.where(id: rolled_taxon_ids)
  end

  def relevant_listed_taxon_alterations
    place_descendant_ids = place.descendants.where('admin_level IN (?)',[0,1,2]).pluck(:id)
    place_with_descendant_ids = [place.id, place_descendant_ids].compact.flatten
    taxon_descendant_ids = taxon.taxon_ancestors_as_ancestor.joins(:taxon).
      where("taxa.is_active = true AND taxa.rank_level <= ?",Taxon::RANK_LEVELS["species"]).
      pluck(:taxon_id)
    scope = ListedTaxonAlteration.joins(:place).where( "place_id IN (?)", place_with_descendant_ids ).
      where("taxon_id IN (?)", taxon_descendant_ids)
    scope
  end
end