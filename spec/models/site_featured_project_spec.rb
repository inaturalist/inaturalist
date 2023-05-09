require "spec_helper.rb"

describe SiteFeaturedProject do
  it { is_expected.to belong_to :site }
  it { is_expected.to belong_to :project }
  it { is_expected.to belong_to :user }

  it { is_expected.to validate_presence_of :site }
  it { is_expected.to validate_presence_of :project }
  it { is_expected.to validate_presence_of :user }
end
