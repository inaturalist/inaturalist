class TaxonSchemeTaxon < ActiveRecord::Base
  belongs_to :taxon_scheme
  belongs_to :taxon
  
  validates_presence_of :taxon_id, :taxon_scheme_id
  
end
