require "spec_helper.rb"

describe Source do
  it { is_expected.to have_many :taxa }
  it { is_expected.to have_many :taxon_names }
  it { is_expected.to have_many :taxon_ranges }
  it { is_expected.to have_many :taxon_changes }
  it { is_expected.to have_many :places }
  it { is_expected.to have_many :taxon_frameworks }
  it { is_expected.to have_many :place_geometries }
  it { is_expected.to belong_to :user }

  it { is_expected.to validate_presence_of :title }
end
