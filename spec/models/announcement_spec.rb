require "spec_helper.rb"

describe Announcement do
  it { is_expected.to have_and_belong_to_many :sites }

  it { is_expected.to validate_presence_of :placement }
  it { is_expected.to validate_presence_of :start }
  it { is_expected.to validate_presence_of :end }
  it { is_expected.to validate_presence_of :body }
end
