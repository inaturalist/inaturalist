require "spec_helper.rb"

describe ControlledTermTaxon do
  it { is_expected.to belong_to(:controlled_term).inverse_of :controlled_term_taxa }
  it { is_expected.to belong_to(:taxon).inverse_of :controlled_term_taxa }
  it { is_expected.to validate_presence_of :controlled_term_id }
  it { is_expected.to validate_presence_of :taxon_id }
end
