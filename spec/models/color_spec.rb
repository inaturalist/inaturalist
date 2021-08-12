require "spec_helper"

describe Color do
  it { is_expected.to have_and_belong_to_many :taxa }
end
