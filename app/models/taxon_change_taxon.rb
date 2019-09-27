class TaxonChangeTaxon < ActiveRecord::Base
  belongs_to :taxon_change, inverse_of: :taxon_change_taxa
  belongs_to :taxon, inverse_of: :taxon_change_taxa

  validates_presence_of :taxon
  validates_presence_of :taxon_change

  after_create :index_taxon
  after_destroy :index_taxon

  def index_taxon
    # unless draft?
    t = taxon || Taxon.find_by_id( taxon_id )
    t.delay( priority: USER_INTEGRITY_PRIORITY ).elastic_index! if t
    true
  end
end
