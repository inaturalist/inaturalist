require "spec_helper.rb"

describe ExternalTaxon do
  it { is_expected.to belong_to :taxon_framework_relationship }
  it { is_expected.to validate_presence_of :name }
  it { is_expected.to validate_presence_of :rank }
  it { is_expected.to validate_presence_of :parent_name }
  it { is_expected.to validate_presence_of :parent_rank }
end
