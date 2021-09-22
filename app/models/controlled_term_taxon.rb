class ControlledTermTaxon < ApplicationRecord
  belongs_to :controlled_term, inverse_of: :controlled_term_taxa
  belongs_to :taxon, inverse_of: :controlled_term_taxa

  after_save :index_controlled_term, :reassess_annotations_after_save_later
  after_destroy :index_controlled_term

  validates_presence_of :controlled_term_id, :taxon_id

  def index_controlled_term
    ids_to_index = [id]
    if controlled_term.is_value?
      ids_to_index += controlled_term.attrs.map(&:id)
    end
    ControlledTerm.elastic_index!( ids: ids_to_index.uniq )
    true
  end

  def reassess_annotations_after_save_later
    Annotation.delay( priority: INTEGRITY_PRIORITY, queue: "slow",
      unique_hash: { "Annotation::reassess_annotations_for_attribute_id": controlled_term_id } ).
      reassess_annotations_for_attribute_id( controlled_term_id )
    true
  end

end
