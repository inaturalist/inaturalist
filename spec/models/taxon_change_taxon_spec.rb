require "spec_helper.rb"

describe TaxonChangeTaxon do
  it { is_expected.to belong_to(:taxon_change).inverse_of :taxon_change_taxa }
  it { is_expected.to belong_to(:taxon).inverse_of :taxon_change_taxa }

  it { is_expected.to validate_presence_of :taxon }
  it { is_expected.to validate_presence_of :taxon_change }
end
