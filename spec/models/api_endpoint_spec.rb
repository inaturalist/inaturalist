require "spec_helper"

describe ApiEndpoint do
  it { is_expected.to have_many :api_endpoint_caches }
end
