class TaxonAncestor < ActiveRecord::Base

  belongs_to :taxon
  belongs_to :ancestor_taxon, class_name: Taxon.to_s, foreign_key: :ancestor_taxon_id

end
