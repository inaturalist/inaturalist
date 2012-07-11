class TaxonChangeTaxon < ActiveRecord::Base
  belongs_to :taxon_change
  belongs_to :taxon

  validates_presence_of :taxon_id, :taxon_change_id
end