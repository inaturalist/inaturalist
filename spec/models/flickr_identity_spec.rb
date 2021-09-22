require "spec_helper.rb"

describe FlickrIdentity do
  it { is_expected.to belong_to :user }
end
