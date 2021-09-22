require "spec_helper.rb"

describe ExplodedAtlasPlace do
  it { is_expected.to belong_to :atlas }
  it { is_expected.to belong_to :place }
  it { is_expected.to validate_uniqueness_of(:atlas_id).scoped_to :place_id }
end
