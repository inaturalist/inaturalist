require "spec_helper.rb"

describe TaxonAncestor do
  it { is_expected.to belong_to :taxon }
  it { is_expected.to belong_to(:ancestor_taxon).class_name('Taxon').with_foreign_key :ancestor_taxon_id }
  it { is_expected.to belong_to(:descendant_taxon).class_name('Taxon').with_foreign_key :taxon_id }
end
