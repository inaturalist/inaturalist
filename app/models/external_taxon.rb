class ExternalTaxon < ActiveRecord::Base
  belongs_to :taxon_reference
  
  after_create :update_taxon_reference
  after_update :update_taxon_reference
  
  #validates_uniqueness_of :name, :scope => :taxon_reference_concept_id
  
  def update_taxon_reference
    return true unless self.taxon_reference
    taxon_reference.set_relationship if (name_changed? || new_record?)
    attrs = {}
    attrs[:relationship] = taxon_reference.relationship
    taxon_reference.update_attributes(attrs)
  end
end
