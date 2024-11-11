# frozen_string_literal: true

require "spec_helper"

describe ObservationGeoScore do
  it { is_expected.to belong_to :observation }
  it { is_expected.to validate_uniqueness_of( :observation_id ) }
end
