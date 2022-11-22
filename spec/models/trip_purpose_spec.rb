require "spec_helper.rb"

describe TripPurpose do
  it { is_expected.to belong_to :trip }
  it { is_expected.to belong_to :resource }
end
