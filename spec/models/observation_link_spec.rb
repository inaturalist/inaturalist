require "spec_helper.rb"

describe ObservationLink do
  subject { build :observation_link }

  it { is_expected.to belong_to :observation }
  it { is_expected.to validate_uniqueness_of(:href).scoped_to :observation_id }
end
