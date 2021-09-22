require "spec_helper"

describe AtlasAlteration do
  it { is_expected.to belong_to :atlas }
  it { is_expected.to belong_to :place }
  it { is_expected.to belong_to :user }
end
