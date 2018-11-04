class Concept < ActiveRecord::Base
  belongs_to :taxon, :inverse_of => :concept
  belongs_to :source
  belongs_to :user
  has_many :taxon_references, dependent: :destroy
  has_many :taxon_curators, inverse_of: :concept, dependent: :destroy
  
  accepts_nested_attributes_for :source
  validate :rank_level_below_taxon_rank
  
  #after save? - relly should be handle change in rank_level (ie no longer a framework...)
  def handle_change_in_completeness
    return true unless complete_changed? || complete_rank_changed?
    Taxon.delay( priority: INTEGRITY_PRIORITY, unique_hash: { "Taxon::reindex_descendants_of": id } ).reindex_descendants_of( id )
    taxon_curators.destroy_all if !complete && complete_was
    TaxonCurator.
      joins( taxon: :taxon_ancestors ).
      where( "taxon_ancestors.ancestor_taxon_id = ?", id ).
      where( "taxa.rank_level < ?", complete_rank_level.to_i ).
      destroy_all
    true
  end
  
  def rank_level_below_taxon_rank
    if rank_level.to_i > taxon.rank_level.to_i
      errors.add( :rank_level, "must be below the taxon rank" )
    end
    true
  end
  
  def framework?
    return true unless rank_level.nil?
    return false
  end

  def get_downstream_concepts
    return false unless framework?
    ancestry_string = taxon.rank == "stateofmatter" ? "#{taxon_id}" : "%/#{taxon_id}"
    downstream_concepts = Concept.includes("taxon").joins("JOIN taxa ON concepts.taxon_id = taxa.id").
      where("(taxa.ancestry LIKE ('#{ancestry_string}/%') OR taxa.ancestry LIKE ('#{ancestry_string}')) AND taxa.rank_level > #{rank_level} AND concepts.rank_level IS NOT NULL")
  end
  
  def concept_taxon_name
    taxon.name
  end
end
