class TaxonScheme < ActiveRecord::Base
  belongs_to :source
  has_many :taxon_scheme_taxa
  has_many :taxa, :through => :taxon_scheme_taxa, :source => :taxon
  
  validates_presence_of :source_id
  
end
