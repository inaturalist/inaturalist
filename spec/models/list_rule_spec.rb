require "spec_helper.rb"

describe ListRule do
  it { is_expected.to belong_to :list }
  it { is_expected.to belong_to :operand }
end
