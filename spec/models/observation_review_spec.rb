require "spec_helper.rb"

describe ObservationReview do
  it { is_expected.to belong_to :observation }
  it { is_expected.to belong_to :user }
end
