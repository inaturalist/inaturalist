require "spec_helper.rb"

describe DeletedObservation do
  it { is_expected.to belong_to :user }
end
