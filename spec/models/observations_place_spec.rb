require "spec_helper.rb"

describe ObservationsPlace do
  it { is_expected.to belong_to :observation }
  it { is_expected.to belong_to :place }
end
