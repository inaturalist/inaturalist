class ExternalTaxon < ActiveRecord::Base
  belongs_to :taxon_framework_relationship
  
  after_create :update_taxon_framework_relationship
  after_update :update_taxon_framework_relationship
  
  def update_taxon_framework_relationship
    return true unless self.taxon_framework_relationship
    taxon_framework_relationship.set_relationship if ( name_changed? || new_record? )
    attrs = {}
    attrs[:relationship] = taxon_framework_relationship.relationship
    taxon_framework_relationship.update_attributes( attrs )
  end
end
