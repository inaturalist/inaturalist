require "spec_helper.rb"

describe ObservationLink do
  it { is_expected.to belong_to :observation }

  xit { is_expected.to validate_uniqueness_of(:href).scoped_to :observation_id }
end
