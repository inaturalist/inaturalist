class ExternalTaxon < ActiveRecord::Base
  belongs_to :taxon_framework_relationship
  
  after_create :update_taxon_framework_relationship
  after_update :update_taxon_framework_relationship
  after_destroy :update_taxon_framework_relationship
  
  before_validation :strip_whitespace
  
  def update_taxon_framework_relationship
    return true unless self.taxon_framework_relationship
    taxon_framework_relationship.set_relationship if ( name_changed? || new_record? )
    attrs = {}
    attrs[:relationship] = taxon_framework_relationship.relationship
    taxon_framework_relationship.update_attributes( attrs )
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
