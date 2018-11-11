class TaxonFramework < ActiveRecord::Base
  belongs_to :taxon, :inverse_of => :taxon_framework
  belongs_to :source
  belongs_to :user
  has_many :taxon_framework_relationships, dependent: :destroy
  has_many :taxon_curators, inverse_of: :taxon_framework, dependent: :destroy
  
  before_save :check_taxon_framework_relationships
  before_save :check_taxon_curators
  after_save :check_other_taxon_framework_relationships
  after_save :handle_change_in_completeness
  
  accepts_nested_attributes_for :source
  validate :rank_level_below_taxon_rank  
  validates :taxon_id, presence: true
  
  def handle_change_in_completeness
    return true unless complete_changed? || rank_level_changed?
    Taxon.delay( priority: INTEGRITY_PRIORITY, unique_hash: { "Taxon::reindex_taxa_covered_by": id } ).reindex_taxa_covered_by( self )
    true
  end
  
  def check_taxon_framework_relationships
    return true if new_record?
    return true if rank_level_was.nil? || source_id_was.nil?
    return true unless rank_level_changed? || source_id_changed? || taxon_id_changed?
    taxon_framework_relationships.destroy_all
    true
  end
  
  def check_other_taxon_framework_relationships
    return true unless rank_level
    return true unless new_record? || rank_level_changed? || source_id_changed? || taxon_id_changed?
    
    upstream_taxon_frameworks = TaxonFramework.where("taxon_id IN (?)", taxon.ancestor_ids).pluck(:id)
    ancestor_string = taxon.rank == "stateofmatter" ? taxon.id.to_s : "%/#{taxon.id}"
    tr = TaxonFrameworkRelationship.joins(:taxa).where("taxon_framework_id IN (?) AND (taxa.id = ? OR taxa.ancestry LIKE (?) OR taxa.ancestry LIKE (?))", upstream_taxon_frameworks, taxon.id, "#{ancestor_string}", "#{ancestor_string}/%")
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
  
  def covers?
    return true unless rank_level.nil?
    return false
  end

  def get_downstream_taxon_frameworks
    return false unless covers?
    ancestry_string = taxon.rank == "stateofmatter" ? "#{taxon_id}" : "%/#{taxon_id}"
    downstream_taxon_frameworks = TaxonFramework.includes("taxon").joins("JOIN taxa ON taxon_frameworks.taxon_id = taxa.id").
      where("(taxa.ancestry LIKE ('#{ancestry_string}/%') OR taxa.ancestry LIKE ('#{ancestry_string}')) AND taxa.rank_level > #{rank_level} AND taxon_frameworks.rank_level IS NOT NULL")
  end
    
  def taxon_framework_taxon_name
    taxon.name
  end
end
