require File.expand_path("../../spec_helper", __FILE__)

describe INatAPIService do

  before :each do
    # stubbing HEAD
    stub_request(:head, /#{INatAPIService::ENDPOINT}/).
      to_return(status: 200, body: "", headers: {})
    # stubbing GET
    stub_request(:get, /#{INatAPIService::ENDPOINT}/).
      to_return(status: 200, body: '{"total_results": 9 }',
        headers: {"Content-Type" => "application/json"})
  end

  it "fetch observations" do
    result = INatAPIService.observations
    expect(result.total_results).to eq 9
  end

  it "fetch observations_observers" do
    result = INatAPIService.observations_observers
    expect(result.total_results).to eq 9
  end

  it "fetch observations_species_counts" do
    result = INatAPIService.observations_species_counts
    expect(result.total_results).to eq 9
  end

end
