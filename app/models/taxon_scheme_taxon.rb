class TaxonSchemeTaxon < ActiveRecord::Base
  belongs_to :taxon_scheme
  belongs_to :taxon
  belongs_to :taxon_name
  
  validates_presence_of :taxon_id, :taxon_scheme_id, :taxon_name
  validates_uniqueness_of :taxon_name_id, :scope => :taxon_scheme_id
  validates_uniqueness_of :taxon_id, :scope => :taxon_scheme_id

  before_validation :set_taxon_name

  def set_taxon_name
    self.taxon_name ||= taxon.scientific_name
    true
  end
  
  def to_s
    "<TaxonSchemeTaxon #{id} taxon_id: #{taxon_id} taxon_name_id: #{taxon_id} taxon_scheme_id: #{taxon_scheme_id}>" 
  end
end
