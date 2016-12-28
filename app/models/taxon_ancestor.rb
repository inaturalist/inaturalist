class TaxonAncestor < ActiveRecord::Base

  belongs_to :taxon
  belongs_to :ancestor_taxon, class_name: Taxon.to_s, foreign_key: :ancestor_taxon_id
  belongs_to :descendant_taxon, class_name: Taxon.to_s, foreign_key: :taxon_id

end
