class ControlledTermTaxon < ActiveRecord::Base
  belongs_to :controlled_term, inverse_of: :controlled_term_taxa
  belongs_to :taxon, inverse_of: :controlled_term_taxa

  after_save :index_controlled_term
  after_destroy :index_controlled_term

  def index_controlled_term
    ids_to_index = [id]
    if controlled_term.is_value?
      ids_to_index += controlled_term.attrs.map(&:id)
    end
    ControlledTerm.elastic_index!( ids: ids_to_index.uniq )
  end
end
