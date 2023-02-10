class ExternalTaxon < ApplicationRecord
  belongs_to :taxon_framework_relationship
  
  after_create :update_taxon_framework_relationship
  after_update :update_taxon_framework_relationship
  after_destroy :update_taxon_framework_relationship
  
  before_validation :strip_whitespace
  
  validates_presence_of :name, :rank, :parent_name, :parent_rank
  validate :must_be_unique_to_taxon_framework

  ADDITIONAL_RANKS = ["cohort", "magnaorder"]
  
  def must_be_unique_to_taxon_framework
    return true unless tfr = TaxonFrameworkRelationship.where(id: taxon_framework_relationship_id).first
    if et = ExternalTaxon.joins("JOIN taxon_framework_relationships tfr ON external_taxa.taxon_framework_relationship_id = tfr.id").
      where("name = ? AND rank = ? AND tfr.taxon_framework_id = ? AND external_taxa.id != ?", name, rank, tfr.taxon_framework_id, id).first
      errors.add(:id, "external taxon with this name and rank already represented in this taxon framework")
    end
    true
  end

  def update_taxon_framework_relationship
    return true unless self.taxon_framework_relationship
    taxon_framework_relationship.set_relationship if ( name_changed? || new_record? )
    attrs = {}
    attrs[:relationship] = taxon_framework_relationship.relationship
    taxon_framework_relationship.update( attrs )
  end
  
  private
  def strip_whitespace
    self.name = self.name.strip unless self.name.nil?
    self.parent_name = self.parent_name.strip unless self.parent_name.nil?
    self.rank = self.rank.strip unless self.rank.nil?
    self.parent_rank = self.parent_rank.strip unless self.parent_rank.nil?
    self.url = self.url.strip unless self.url.nil?
  end
  
end
