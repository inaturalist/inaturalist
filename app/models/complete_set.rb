class CompleteSet < ActiveRecord::Base
  has_subscribers
  belongs_to :taxon
  belongs_to :user
  belongs_to :place
  belongs_to :source
  has_many :comments, :as => :parent, :dependent => :destroy
  
  def get_taxa_for_place_taxon
    place_descendants = [place, place.descendants.where('admin_level IN (?)',[0,1,2]).pluck(:id)].compact.flatten
    taxon_ids = ListedTaxon.joins( { list: :check_list_place } ).where( "lists.type = 'CheckList'").
    where( "listed_taxa.taxon_id IN (?)", taxon.taxon_ancestors_as_ancestor.joins(:taxon).where("taxa.is_active = true AND taxa.rank_level <= ?",Taxon::RANK_LEVELS["species"]).pluck(:taxon_id) ).
    where("listed_taxa.place_id IN (?)", place_descendants).pluck(:taxon_id).uniq #these are all listed sp+spp in places/desc places
    rolled_taxon_ids = Taxon.where(id: taxon_ids).map{|t| (t.rank_level && t.rank_level < Taxon::RANK_LEVELS["species"]) ?  t.ancestor_ids.last : t.id} #roll spp up to sp
    Taxon.where(id: rolled_taxon_ids)
  end
  
  def relevant_listed_taxon_alterations
    place_descendants = [place, place.descendants.where('admin_level IN (?)',[0,1,2]).pluck(:id)].compact.flatten
    scope = ListedTaxonAlteration.joins(:place).where( "place_id IN (?)", place_descendants ).
    where("taxon_id IN (?)", taxon.taxon_ancestors_as_ancestor.joins(:taxon).where("taxa.is_active = true AND taxa.rank_level <= ?",Taxon::RANK_LEVELS["species"]).pluck(:taxon_id))
    scope
  end
end