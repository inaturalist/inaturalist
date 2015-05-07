require "spec_helper"

describe "Observation Index" do
  it "as_indexed_json should return a hash" do
    o = Observation.make!
    json = o.as_indexed_json
    expect( json ).to be_a Hash
  end

  it "sets location based on private coordinates if exist" do
    o = Observation.make!(latitude: 3.0, longitude: 4.0)
    o.update_attributes(private_latitude: 1.0, private_longitude: 2.0)
    json = o.as_indexed_json
    expect( json[:location] ).to eq "1.0,2.0"
  end

  it "sets location based on public coordinates if there are no private" do
    o = Observation.make!(latitude: 3.0, longitude: 4.0)
    json = o.as_indexed_json
    expect( json[:location] ).to eq "3.0,4.0"
  end
end
