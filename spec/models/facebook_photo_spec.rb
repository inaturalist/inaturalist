require "spec_helper.rb"

describe FacebookPhoto do
  it { is_expected.to validate_presence_of :native_photo_id }
end
