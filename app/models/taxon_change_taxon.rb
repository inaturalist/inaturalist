class TaxonChangeTaxon < ActiveRecord::Base
  belongs_to :taxon_change
  belongs_to :taxon

end