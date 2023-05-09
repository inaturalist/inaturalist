require "spec_helper.rb"

describe ListedTaxonAlteration do
  it { is_expected.to belong_to :taxon }
  it { is_expected.to belong_to :place }
  it { is_expected.to belong_to :user }
end
