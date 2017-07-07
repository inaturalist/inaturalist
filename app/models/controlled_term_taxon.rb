class ControlledTermTaxon < ActiveRecord::Base
  belongs_to :controlled_term, inverse_of: :controlled_term_taxa
  belongs_to :taxon, inverse_of: :controlled_term_taxa
end