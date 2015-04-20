require "spec_helper"

describe "Place Index" do
  it "as_indexed_json should return a hash" do
    p = Place.make!
    json = p.as_indexed_json
    expect( json ).to be_a Hash
  end
end
