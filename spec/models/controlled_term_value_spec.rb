require "spec_helper.rb"

describe ControlledTermValue do
  it { is_expected.to validate_presence_of :controlled_value_id }
  it { is_expected.to validate_presence_of :controlled_attribute_id }
  it { is_expected.to validate_uniqueness_of(:controlled_value_id).scoped_to(:controlled_attribute_id) }
end
