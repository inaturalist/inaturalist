class TaxonSchemeTaxon < ActiveRecord::Base
  belongs_to :taxon_scheme
  belongs_to :taxon
  
  validates_presence_of :taxon_id, :taxon_scheme_id
  validates_uniqueness_of :taxon_id, :scope => :taxon_scheme_id
  
  def to_s
    "<TaxonSchemeTaxon #{id} taxon_id: #{taxon_id} taxon_scheme_id: #{taxon_scheme_id}>" 
  end
end
