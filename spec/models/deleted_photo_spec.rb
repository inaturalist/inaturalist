require "spec_helper.rb"

describe DeletedPhoto do
  it { is_expected.to belong_to :user }
  it { is_expected.to belong_to :photo }
end
