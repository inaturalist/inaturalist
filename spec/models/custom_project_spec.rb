require "spec_helper.rb"

describe CustomProject do
  it { is_expected.to belong_to :project }
  it { is_expected.to validate_presence_of :project_id }
end
