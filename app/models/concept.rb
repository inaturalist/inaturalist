class Concept < ActiveRecord::Base
  belongs_to :taxon, :inverse_of => :concept
  belongs_to :source
  belongs_to :user
  has_many :taxon_references, dependent: :destroy
  has_many :taxon_curators, inverse_of: :concept, dependent: :destroy
  
  before_save :check_taxon_references
  before_save :check_taxon_curators
  after_save :check_other_concept_taxon_references
  
  accepts_nested_attributes_for :source
  validate :rank_level_below_taxon_rank  
  validates :taxon_id, presence: true
  
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
  
  def check_taxon_references
    return true if new_record?
    return true if rank_level_was.nil? || source_id_was.nil?
    return true unless rank_level_changed? || source_id_changed? || taxon_id_changed?
    taxon_references.destroy_all
    true
  end
  
  def check_other_concept_taxon_references
    return true unless rank_level
    return true unless new_record? || rank_level_changed? || source_id_changed? || taxon_id_changed?
    
    upstream_concepts = Concept.where("taxon_id IN (?)", taxon.ancestor_ids).pluck(:id)
    ancestor_string = taxon.rank == "stateofmatter" ? taxon.id.to_s : "%/#{taxon.id}"
    tr = TaxonReference.joins(:taxa).where("concept_id IN (?) AND (taxa.id = ? OR taxa.ancestry LIKE (?) OR taxa.ancestry LIKE (?))", upstream_concepts, taxon.id, "#{ancestor_string}", "#{ancestor_string}/%")
    return tr.destroy_all
  end
  
  def check_taxon_curators
    return true if new_record?
    return true if rank_level_was.nil?
    return true unless rank_level_changed? && rank_level.nil?
    taxon_curators.destroy_all
    true
  end
  
  def rank_level_below_taxon_rank
    return  true if rank_level.nil?
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
